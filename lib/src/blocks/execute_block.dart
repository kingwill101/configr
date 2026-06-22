import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:i3config/i3config_v2.dart' as i3;

/// Block handler for the `execute` config action.
///
/// Runs a shell command with configurable environment, timeout, and working
/// directory. Rollback is a no-op (commands cannot be un-executed).
///
/// ```i3
/// execute {
///   command = "echo hello"
///   working_directory = "/tmp"
///   timeout = 60
///   inherit_environment = true
/// }
/// ```
class ExecuteBlock extends ActionBlock {
  @override
  String get blockType => 'execute';

  String command = '';
  String? workingDirectory;
  int timeoutSeconds = 300;
  Map<String, String> environment = const {};
  String? input;
  bool inheritEnvironment = true;

  // Execution state
  String? stdout;
  String? stderr;
  int exitCode = -1;

  ExecuteBlock({super.fileSystem, super.eventBus});

  @override
  Map<String, String> get additionalProperties => {
    if (command.isNotEmpty) 'command': command,
    if (workingDirectory != null) 'working_directory': workingDirectory!,
    if (timeoutSeconds != 300) 'timeout': timeoutSeconds.toString(),
    if (input != null) 'input': input!,
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (!inheritEnvironment) 'inherit_environment': inheritEnvironment,
  };

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    command = (context.getVariable('command') as String?) ?? command;
    workingDirectory = context.getVariable('working_directory') as String?;

    final to = context.getVariable('timeout');
    if (to is int) timeoutSeconds = to;
    if (to is String) timeoutSeconds = int.tryParse(to) ?? 300;

    final env = context.getVariable('environment');
    if (env is Map) {
      environment = env.cast<String, String>();
    }

    input = context.getVariable('input') as String?;
    inheritEnvironment = switch (context.getVariable('inherit_environment')) {
      false || 'false' => false,
      _ => true,
    };
  }

  @override
  Future<void> execute() async {
    emitEvent(StartedEvent(moduleId: id, message: 'Executing: $command'));

    if (command.isEmpty) {
      throw ActionFailedException(
        'Execute block requires a command',
        moduleId: id,
      );
    }

    final startTime = DateTime.now();
    try {
      final result = await _executeWithTimeout();
      final duration = DateTime.now().difference(startTime);

      stdout = result.stdout.toString();
      stderr = result.stderr.toString();
      exitCode = result.exitCode;

      if (result.exitCode != 0) {
        throw ActionFailedException(
          'Command failed with exit code ${result.exitCode}: $stderr',
          moduleId: id,
        );
      }

      logger.info('Command completed in ${duration.inMilliseconds}ms');
      emitEvent(
        CompletedEvent(
          moduleId: id,
          message: 'Command completed in ${duration.inMilliseconds}ms',
        ),
      );
    } catch (e, s) {
      if (e is ActionFailedException) rethrow;
      emitEvent(
        FailedEvent(moduleId: id, message: 'Command execution failed: $e'),
      );
      throw ActionFailedException(
        'Failed to execute: $command',
        moduleId: id,
        cause: e,
        stackTrace: s,
      );
    }

    status = 'completed';
  }

  @override
  Future<void> rollback() async {
    // Commands cannot be un-executed.
    logger.warning('Cannot rollback executed command: $command');
  }

  Future<ProcessResult> _executeWithTimeout() async {
    final env = <String, String>{};
    if (inheritEnvironment) {
      env.addAll(Platform.environment);
    }
    env.addAll(environment);

    final workingDir = workingDirectory ?? Directory.current.path;

    final process = await Process.start(
      'sh',
      ['-c', command],
      environment: env,
      workingDirectory: workingDir,
    );

    if (input != null) {
      process.stdin.write(input);
      await process.stdin.close();
    }

    final stdoutBuf = StringBuffer();
    final stderrBuf = StringBuffer();

    await Future.wait([
      process.stdout.transform(utf8.decoder).forEach((d) => stdoutBuf.write(d)),
      process.stderr.transform(utf8.decoder).forEach((d) => stderrBuf.write(d)),
    ]);

    final code = await process.exitCode;
    return ProcessResult(
      process.pid,
      code,
      stdoutBuf.toString(),
      stderrBuf.toString(),
    );
  }
}
