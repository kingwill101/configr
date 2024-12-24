import 'dart:io';

import 'package:configr/exceptions.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/logging.dart';

class FileExecuteModule extends ResourceModule {
  FileExecuteModule(super.file, super.action,
      {super.allowedActions = const ['execute'], super.fileSystem});

  @override
  Future<void> call() async {
    final command = action.properties['command'] as String;
    final onSuccess = action.properties['on_success'] == 'true';

    await executeModules();
    if (isRollingBack) {
      return;
    }

    if (!onSuccess || (onSuccess && action.status == 'completed')) {
      logger.info('Executing command: $command');
      try {
        final result = await Process.run('sh', ['-c', command]);
        if (result.exitCode != 0) {
          throw CommandExecutionException(command, result.stderr);
        }
        logger.info('Command executed successfully: ${result.stdout}');
      } catch (e, s) {
        throw ActionFailedException(
            'Failed to execute command: $command', e, s);
      }
    } else {
      logger.info('Skipping command execution due to previous action failure');
    }

    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
  }

  @override
  Future<void> rollback() async {
    // Execution cannot be rolled back, but we can log the attempt
    logger.warning('Cannot rollback executed command');

    for (var module in childModules) {
      await module.rollback();
    }
  }
}
