import 'package:configr/events/module_events.dart';
import 'package:configr/exceptions.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/file_utils.dart';
import 'package:configr/utils/logging.dart';
import 'package:configr/utils/event_bus.dart';
import 'package:path/path.dart';

class FileSymlinkModule extends ResourceModule {
  // State getters
  bool get hadToCreateDstDir => state['hadToCreateDstDir'] as bool? ?? false;
  bool get symlinkExisted => state['symlinkExisted'] as bool? ?? false;
  String? get originalTarget => state['originalTarget'] as String?;
  bool get sourceExists => state['sourceExists'] as bool? ?? false;

  FileSymlinkModule(super.file, super.action,
      {super.allowedActions = const ['symlink'], super.fileSystem}) {
    updateState({
      'hadToCreateDstDir': false,
      'symlinkExisted': false,
      'originalTarget': null,
      'sourceExists': false
    });
  }

  @override
  Future<void> execute() async {
    emitEvent(StartedEvent(moduleId: action.id, message: 'Creating symlink'));
    final sourcePath = absolute(source);
    final symlinkDir = dirname(destination);

    emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Source path: $sourcePath'));
    emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Target path: $destination'));

    final exists = await FileUtils.pathExists(sourcePath, fileSystem: fileSystem);
    updateState({'sourceExists': exists.exists});

    if (!exists.exists) {
      throw SourceNotFoundException(sourcePath);
    }

    executeModules();
    if (isRollingBack) {
      return;
    }

    try {
      if (!await FileUtils.directoryExists(symlinkDir, fileSystem: fileSystem)) {
        logger.info('Creating directory $symlinkDir');
        await FileUtils.createDirectory(symlinkDir, fileSystem: fileSystem);
        updateState({'hadToCreateDstDir': true});
      }

      if (await FileUtils.isSymlink(destination, fileSystem: fileSystem)) {
        final target = await FileUtils.readSymlink(destination, fileSystem: fileSystem);
        updateState({
          'symlinkExisted': true,
          'originalTarget': target
        });
        logger.info('Symlink $destination already exists and points to $target');
        emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Existing symlink found'));
      } else {
        logger.info('Creating symlink from $sourcePath to $destination');
        await FileUtils.createSymlink(sourcePath, destination, fileSystem: fileSystem);
        updateState({'symlinkCreated': true});
      }
    } catch (e, st) {
      updateState({
        'error': e.toString(),
        'stackTrace': st.toString()
      });
      throw SymlinkCreationException(destination, e);
    }

    emitEvent(CompletedEvent(moduleId: action.id, message: 'Symlink created successfully'));
    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
    await saveState();
  }

  @override
  Future<void> rollback() async {
    emitEvent(StartedEvent(moduleId: action.id, message: 'Rolling back symlink creation'));
    emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Removing symlink'));
    try {
      if (await FileUtils.isSymlink(destination, fileSystem: fileSystem)) {
        logger.info('Deleting symlink $destination');
        await FileUtils.deleteFile(destination, fileSystem: fileSystem);
      }

      if (symlinkExisted && originalTarget != null) {
        logger.info('Restoring original symlink $destination to point to $originalTarget');
        await FileUtils.createSymlink(originalTarget!, destination, fileSystem: fileSystem);
      }

      if (hadToCreateDstDir) {
        final symlinkDir = dirname(destination);
        if (await FileUtils.directoryExists(symlinkDir)) {
          logger.info('Deleting created directory $symlinkDir');
          await FileUtils.deleteDirectory(symlinkDir, recursive: true, fileSystem: fileSystem);
        }
      }
      updateState({'rollbackCompleted': true});
    } catch (e, st) {
      updateState({
        'rollbackError': e.toString(),
        'rollbackStackTrace': st.toString()
      });
      rethrow;
    }

    for (var module in childModules) {
      await module.rollback();
    }
    
    emitEvent(CompletedEvent(moduleId: action.id, message: 'Rollback completed'));
    await saveState();
  }
}