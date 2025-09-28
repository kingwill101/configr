import 'dart:io';
import 'package:configr/events/module_events.dart';
import 'package:configr/exceptions.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/logging.dart';
import 'package:configr/utils/event_bus.dart';

class FileExecuteModule extends ResourceModule {
  // State getters
  String get command => state['command'] as String? ?? '';
  bool get onSuccess => state['onSuccess'] as bool? ?? false;
  String? get stdout => state['stdout'] as String?;
  String? get stderr => state['stderr'] as String?;
  int get exitCode => state['exitCode'] as int? ?? -1;

  FileExecuteModule(super.file, super.action,
      {super.allowedActions = const ['execute'], super.fileSystem}) {
    updateState({
      'command': '',
      'onSuccess': false,
      'stdout': null,
      'stderr': null,
      'exitCode': -1
    });
  }

  @override
  Future<void> execute() async {
    emitEvent(StartedEvent(moduleId: action.id, message: 'Starting command execution'));
    updateState({
      'command': action.properties['command'] as String,
      'onSuccess': action.properties['on_success'] == 'true'
    });

    await executeModules();
    if (isRollingBack) {
      return;
    }

    if (!onSuccess || (onSuccess && action.status == 'completed')) {
      emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Executing command: $command'));
      logger.info('Executing command: $command');
      try {
        final result = await Process.run('sh', ['-c', command]);
        updateState({
          'stdout': result.stdout.toString(),
          'stderr': result.stderr.toString(),
          'exitCode': result.exitCode,
          'executionCompleted': true
        });

        if (result.exitCode != 0) {
          throw CommandExecutionException(command, result.stderr);
        }
        logger.info('Command executed successfully: ${result.stdout}');
        emitEvent(CompletedEvent(moduleId: action.id, message: 'Command execution completed successfully'));
      } catch (e, s) {
        updateState({
          'error': e.toString(),
          'stackTrace': s.toString()
        });
        emitEvent(FailedEvent(moduleId: action.id, message: 'Command execution failed: ${e.toString()}'));
        throw ActionFailedException('Failed to execute command: $command', e, s);
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
    logger.warning('Cannot rollback executed command');
    updateState({'rollbackAttempted': true});

    for (var module in childModules) {
      await module.rollback();
    }
    
    await saveState();
  }
}