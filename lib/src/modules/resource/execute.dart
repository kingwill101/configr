import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/modules/resource/resource_module.dart';
import 'package:configr/src/utils/logging.dart';

/// Enhanced command execution module with environment management, timeouts, and process monitoring.
/// 
/// Features:
/// - Environment variable management and inheritance
/// - Configurable execution timeouts
/// - Process monitoring and resource tracking
/// - Input/output stream handling
/// - Working directory management
/// - Comprehensive event emission
/// - Execution result validation
class FileExecuteModule extends ResourceModule {
  // State getters
  String get command => state['command'] as String? ?? '';
  bool get onSuccess => state['onSuccess'] as bool? ?? false;
  String? get stdout => state['stdout'] as String?;
  String? get stderr => state['stderr'] as String?;
  int get exitCode => state['exitCode'] as int? ?? -1;

  // Enhanced features
  Map<String, String> get environment => Map<String, String>.from(state['environment'] as Map<String, dynamic>? ?? {});
  String? get workingDirectory => state['workingDirectory'] as String?;
  Duration get timeout => Duration(seconds: state['timeout'] as int? ?? 300); // 5 minutes default
  String? get input => state['input'] as String?;
  bool get inheritEnvironment => state['inheritEnvironment'] as bool? ?? true;
  bool get runInBackground => state['runInBackground'] as bool? ?? false;
  int get maxOutputSize => state['maxOutputSize'] as int? ?? 1024 * 1024; // 1MB default
  Duration get executionDuration => Duration(milliseconds: state['executionDuration'] as int? ?? 0);
  int get processId => state['processId'] as int? ?? -1;
  bool get wasKilled => state['wasKilled'] as bool? ?? false;

  FileExecuteModule(super.file, super.action,
      {super.allowedActions = const ['execute'], super.fileSystem, super.eventBus}) {
    updateState({
      'command': '',
      'onSuccess': false,
      'stdout': null,
      'stderr': null,
      'exitCode': -1,
      'environment': <String, String>{},
      'workingDirectory': null,
      'timeout': 300,
      'input': null,
      'inheritEnvironment': true,
      'runInBackground': false,
      'maxOutputSize': 1024 * 1024,
      'executionDuration': 0,
      'processId': -1,
      'wasKilled': false,
    });
  }

  @override
  Future<void> execute() async {
    emitEvent(StartedEvent(moduleId: action.id, message: 'Starting command execution'));
    
    // Parse configuration
    final config = _parseConfiguration();
    updateState({
      'command': action.properties['command'] as String? ?? '',
      'onSuccess': action.properties['on_success'] == 'true',
      ...config,
    });

    await executeModules();
    if (isRollingBack) {
      return;
    }

    if (!onSuccess || (onSuccess && action.status == 'completed')) {
      emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Executing command: $command'));
      logger.info('Executing command: $command');
      
      final startTime = DateTime.now();
      try {
        final result = await _executeWithTimeout();
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);
        
        updateState({
          'stdout': result.stdout.toString(),
          'stderr': result.stderr.toString(),
          'exitCode': result.exitCode,
          'executionDuration': duration.inMilliseconds,
          'executionCompleted': true
        });

        if (result.exitCode != 0) {
          throw ActionFailedException(
            'Command failed with exit code ${result.exitCode}: ${result.stderr}',
            moduleId: action.id,
            cause: result.stderr,
          );
        }
        logger.info('Command executed successfully: ${result.stdout}');
        emitEvent(CompletedEvent(moduleId: action.id, message: 'Command execution completed successfully in ${duration.inMilliseconds}ms'));
      } catch (e, s) {
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);
        
        updateState({
          'error': e.toString(),
          'stackTrace': s.toString(),
          'executionDuration': duration.inMilliseconds,
        });
        emitEvent(FailedEvent(moduleId: action.id, message: 'Command execution failed: ${e.toString()}'));
        throw ActionFailedException('Failed to execute command: $command', moduleId: action.id, cause: e, stackTrace: s);
      }
    } else {
      logger.info('Skipping command execution due to previous action failure');
      updateState({'skipped': true});
    }

    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
    await saveState();
  }

  @override
  Future<void> rollback() async {
    emitEvent(StartedEvent(moduleId: action.id, message: 'Rolling back execute operation'));
    
    try {
      logger.warning('Cannot rollback executed command');
      updateState({'rollbackAttempted': true});

      for (var module in childModules) {
        await module.rollback();
      }

      emitEvent(CompletedEvent(moduleId: action.id, message: 'Execute rollback completed (no-op)'));
      await saveState();
    } catch (e, st) {
      updateState({
        'rollbackError': e.toString(),
        'rollbackStackTrace': st.toString()
      });
      emitEvent(FailedEvent(moduleId: action.id, message: 'Execute rollback failed: ${e.toString()}'));
      rethrow;
    }
  }

  /// Parse configuration from action properties.
  /// 
  /// Extracts environment variables, timeout settings, working directory,
  /// and other configuration options from the action properties.
  Map<String, dynamic> _parseConfiguration() {
    final env = <String, String>{};
    
    // Parse environment variables
    if (action.properties.containsKey('environment')) {
      final envData = action.properties['environment'];
      if (envData is Map) {
        env.addAll(Map<String, String>.from(envData));
      }
    }
    
    // Parse timeout
    int timeoutSeconds = 300; // 5 minutes default
    if (action.properties.containsKey('timeout')) {
      final timeoutValue = action.properties['timeout'];
      if (timeoutValue is int) {
        timeoutSeconds = timeoutValue;
      } else if (timeoutValue is String) {
        timeoutSeconds = int.tryParse(timeoutValue) ?? 300;
      }
    }
    
    return {
      'environment': env,
      'workingDirectory': action.properties['working_directory'],
      'timeout': timeoutSeconds,
      'input': action.properties['input'],
      'inheritEnvironment': action.properties['inherit_environment'] != 'false',
      'runInBackground': action.properties['run_in_background'] == 'true',
      'maxOutputSize': int.tryParse(action.properties['max_output_size']?.toString() ?? '') ?? 1024 * 1024,
    };
  }

  /// Execute command with timeout and enhanced features.
  Future<ProcessResult> _executeWithTimeout() async {
    // Prepare environment
    final env = <String, String>{};
    if (inheritEnvironment) {
      env.addAll(Platform.environment);
    }
    env.addAll(environment);
    
    // Prepare working directory
    final workingDir = workingDirectory ?? Directory.current.path;
    
    // Start process
    final process = await Process.start(
      'sh',
      ['-c', command],
      environment: env,
      workingDirectory: workingDir,
    );
    
    updateState({'processId': process.pid});
    
    // Handle input if provided
    if (input != null) {
      process.stdin.write(input);
      await process.stdin.close();
    }
    
    // Collect output with size limits
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    
    final stdoutSubscription = process.stdout
        .transform(utf8.decoder)
        .listen((data) {
      if (stdoutBuffer.length + data.length <= maxOutputSize) {
        stdoutBuffer.write(data);
      }
    });
    
    final stderrSubscription = process.stderr
        .transform(utf8.decoder)
        .listen((data) {
      if (stderrBuffer.length + data.length <= maxOutputSize) {
        stderrBuffer.write(data);
      }
    });
    
    // Wait for completion with timeout
    try {
      final exitCode = await process.exitCode.timeout(timeout);
      
      await stdoutSubscription.cancel();
      await stderrSubscription.cancel();
      
      return ProcessResult(
        process.pid,
        exitCode,
        stdoutBuffer.toString(),
        stderrBuffer.toString(),
      );
    } on TimeoutException {
      // Kill the process if it times out
      process.kill();
      updateState({'wasKilled': true});
      
      await stdoutSubscription.cancel();
      await stderrSubscription.cancel();
      
      throw ActionFailedException(
        'Command timed out after ${timeout.inSeconds} seconds',
        moduleId: action.id,
      );
    }
  }
}