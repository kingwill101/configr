import 'dart:io';

import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/execution_service.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:configr/src/utils/shell_type.dart';
import 'package:i3config/i3config_v2.dart' as i3;

class ExecuteBlock extends ActionBlock {
  @override
  String get blockType => 'execute';

  String command = '';
  String? workingDirectory;
  int timeoutSeconds = 300;
  Map<String, String> environment = const {};
  String? input;
  bool inheritEnvironment = true;
  ShellType shell = ShellType.sh;
  bool _shellExplicit = false;

  String? stdout;
  String? stderr;
  int exitCode = -1;

  ExecuteBlock();

  @override
  Map<String, String> get additionalProperties => {
    if (command.isNotEmpty) 'command': command,
    'working_directory': ?workingDirectory,
    if (timeoutSeconds != 300) 'timeout': timeoutSeconds.toString(),
    'input': ?input,
    if (_shellExplicit) 'shell': shell.name,
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

    final shellStr = context.getVariable('shell') as String?;
    if (shellStr != null) {
      shell = ShellType.tryParse(shellStr) ?? ShellType.sh;
      _shellExplicit = true;
    }
  }

  @override
  void resetState() {
    super.resetState();
    command = '';
    workingDirectory = null;
    timeoutSeconds = 300;
    environment = const {};
    input = null;
    inheritEnvironment = true;
    shell = ShellType.sh;
    _shellExplicit = false;
    stdout = null;
    stderr = null;
    exitCode = -1;
  }

  @override
  String dryRunSummary() =>
      command.isNotEmpty ? '$blockType: $command' : super.dryRunSummary();

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
    logger.warning('Cannot rollback executed command: $command');
  }

  Future<ProcessResult> _executeWithTimeout() async {
    final env = <String, String>{};
    if (inheritEnvironment && executionService is LocalExecutionService) {
      env.addAll(Platform.environment);
    }
    env.addAll(environment);

    final workingDir =
        workingDirectory ??
        (executionService is LocalExecutionService
            ? fileSystem.currentDirectory.path
            : null);
    final effectiveShell = _effectiveShell();
    final executable = effectiveShell.defaultExecutable;
    final args = effectiveShell.scriptArgs(command);

    return executionService.run(
      executable,
      args,
      environment: env,
      workingDirectory: workingDir,
      stdin: input,
    );
  }

  ShellType _effectiveShell() {
    if (_shellExplicit) return shell;
    final platform = executionService.platform.toLowerCase();
    if (platform.contains('windows')) return ShellType.powershell;
    return ShellType.sh;
  }
}
