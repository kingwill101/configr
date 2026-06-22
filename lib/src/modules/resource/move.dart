import 'package:configr/src/exceptions.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/modules/resource/resource_module.dart';
import 'package:configr/src/utils/file_utils.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:path/path.dart';

class FileMoveModule extends ResourceModule {
  // State getters
  bool get hadToCreateDstDir => state['hadToCreateDstDir'] as bool? ?? false;
  bool get destinationFileExisted => state['destinationFileExisted'] as bool? ?? false;
  String? get originalPath => state['originalPath'] as String?;
  bool get overwrite => state['overwrite'] as bool? ?? false;

  FileMoveModule(super.file, super.action,
      {super.allowedActions = const ['move'], super.fileSystem, super.eventBus}) {
    updateState({
      'hadToCreateDstDir': false,
      'destinationFileExisted': false,
      'originalPath': null,
      'overwrite': false
    });
  }

  @override
  Future<void> execute() async {
    final sourcePath = source;
    final destinationPath = file.destination;
    final destinationDir = dirname(destinationPath);

    updateState({
      'overwrite': action.properties.containsKey('overwrite') &&
          action.properties['overwrite'] == 'true'
    });

    if (!await FileUtils.fileExists(sourcePath, fileSystem: fileSystem)) {
      throw SourceNotFoundException(sourcePath);
    }

    await executeModules();
    if (isRollingBack) {
      return;
    }

    if (!await FileUtils.directoryExists(destinationDir, fileSystem: fileSystem)) {
      logger.info('Creating directory $destinationDir');
      try {
        await FileUtils.createDirectory(destinationDir, fileSystem: fileSystem);
        updateState({'hadToCreateDstDir': true});
      } catch (e, stackTrace) {
        updateState({
          'error': e.toString(),
          'stackTrace': stackTrace.toString()
        });
        throw ActionFailedException(
            'Failed to create destination directory $destinationDir',
            moduleId: action.id,
            cause: e,
            stackTrace: stackTrace);
      }
    }

    final exists = await FileUtils.fileExists(destinationPath, fileSystem: fileSystem);
    updateState({
      'destinationFileExisted': exists,
      'originalPath': sourcePath
    });

    if (exists && !overwrite) {
      logger.severe(
          'Destination file $destinationPath already exists and overwrite is not allowed');
      throw DestinationExistsException(destinationPath);
    }

    logger.info('Moving file from $sourcePath to $destinationPath');
    try {
      await FileUtils.moveFile(sourcePath, destinationPath, fileSystem: fileSystem);
      updateState({'moveCompleted': true});
    } catch (e, st) {
      updateState({
        'error': e.toString(),
        'stackTrace': st.toString()
      });
      rethrow;
    }

    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
    await saveState();
  }

  @override
  Future<void> rollback() async {
    emitEvent(StartedEvent(moduleId: action.id, message: 'Rolling back move operation'));
    
    try {
      if (originalPath != null) {
        logger.info('Moving file back from $destination to $originalPath');
        await FileUtils.moveFile(destination, originalPath!, fileSystem: fileSystem);
      }

      if (hadToCreateDstDir) {
        final destinationDir = dirname(destination);
        if (await FileUtils.directoryExists(destinationDir)) {
          logger.info('Deleting created directory $destinationDir');
          await FileUtils.deleteDirectory(destinationDir,
              recursive: true, fileSystem: fileSystem);
        }
      }

      for (var module in childModules) {
        await module.rollback();
      }

      updateState({'rollbackCompleted': true});
      emitEvent(CompletedEvent(moduleId: action.id, message: 'Move rollback completed'));
      await saveState();
    } catch (e, st) {
      updateState({
        'rollbackError': e.toString(),
        'rollbackStackTrace': st.toString()
      });
      emitEvent(FailedEvent(moduleId: action.id, message: 'Move rollback failed: ${e.toString()}'));
      rethrow;
    }
  }
}
