import 'package:configr/events/module_events.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/file_utils.dart';
import 'package:configr/utils/logging.dart';
import 'package:configr/utils/event_bus.dart';

class FileDeleteModule extends ResourceModule {
  // State getters
  String? get backupPath => state['backupPath'] as String?;
  bool get fileExisted => state['fileExisted'] as bool? ?? false;
  bool get backupCreated => state['backupCreated'] as bool? ?? false;
  bool get isDirectory => state['isDirectory'] as bool? ?? false;
  bool get recursive => state['recursive'] as bool? ?? false;

  FileDeleteModule(
    super.file,
    super.action, {
    super.allowedActions = const ['delete'],
    super.fileSystem,
  }) {
    updateState({
      'backupPath': null,
      'fileExisted': false,
      'backupCreated': false,
      'isDirectory': false,
      'recursive': false,
    });
  }

  @override
  Future<void> execute() async {
    emitEvent(
      StartedEvent(
        moduleId: action.id,
        message: 'Starting deletion of $source',
      ),
    );
    final sourcePath = source;

    // Check if recursive option is enabled
    final recursiveOption = action.properties['recursive'] as bool? ?? false;
    updateState({'recursive': recursiveOption});

    // Check if source exists and determine if it's a file or directory
    final fileExists = await FileUtils.fileExists(
      sourcePath,
      fileSystem: fileSystem,
    );
    final directoryExists = await FileUtils.directoryExists(
      sourcePath,
      fileSystem: fileSystem,
    );
    final exists = fileExists || directoryExists;

    updateState({'fileExisted': exists, 'isDirectory': directoryExists});

    if (!exists) {
      logger.warning('Path $sourcePath does not exist, skipping deletion');
      return;
    }

    await executeModules();
    if (isRollingBack) {
      return;
    }

    try {
      if (action.properties.containsKey('backup')) {
        final backupPathValue = action.properties['backup']['backup_path'];
        updateState({'backupPath': backupPathValue});

        logger.info('Backing up file $sourcePath to $backupPath');
        await FileUtils.copyFile(
          sourcePath,
          backupPath!,
          fileSystem: fileSystem,
        );
        updateState({'backupCreated': true});
      }

      emitEvent(
        StatusUpdateEvent(
          moduleId: action.id,
          level: StatusEvent.info,
          message: 'Deleting files...',
        ),
      );

      if (isDirectory) {
        logger.info('Deleting directory $sourcePath (recursive: $recursive)');
        await FileUtils.deleteDirectory(
          sourcePath,
          fileSystem: fileSystem,
          recursive: recursive,
        );
      } else {
        logger.info('Deleting file $sourcePath');
        await FileUtils.deleteFile(sourcePath, fileSystem: fileSystem);
      }
      updateState({'deleteCompleted': true});
      emitEvent(
        CompletedEvent(
          moduleId: action.id,
          message: 'Deletion completed successfully',
        ),
      );
    } catch (e, st) {
      updateState({'error': e.toString(), 'stackTrace': st.toString()});
      emitEvent(
        FailedEvent(
          moduleId: action.id,
          message: 'Deletion failed: ${e.toString()}',
        ),
      );
      rethrow;
    }

    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
    await saveState();
  }

  @override
  Future<void> rollback() async {
    try {
      if (fileExisted && backupPath != null && backupCreated) {
        logger.info('Restoring file from $backupPath to $source');
        await FileUtils.copyFile(backupPath!, source, fileSystem: fileSystem);
        await FileUtils.deleteFile(backupPath!, fileSystem: fileSystem);
        updateState({'rollbackCompleted': true});
      }
    } catch (e, st) {
      updateState({
        'rollbackError': e.toString(),
        'rollbackStackTrace': st.toString(),
      });
      rethrow;
    }

    for (var module in childModules) {
      await module.rollback();
    }

    await saveState();
  }
}
