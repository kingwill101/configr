import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/modules/resource/resource_module.dart';
import 'package:configr/src/utils/file_utils.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:path/path.dart' as path;

class FileRenameModule extends ResourceModule {
  // State getters
  String? get originalName => state['originalName'] as String?;
  bool get destinationFileExisted => state['destinationFileExisted'] as bool? ?? false;
  bool get overwrite => state['overwrite'] as bool? ?? false;

  FileRenameModule(super.file, super.action,
      {super.allowedActions = const ['rename'], super.fileSystem, super.eventBus}) {
    updateState({
      'originalName': null,
      'destinationFileExisted': false,
      'overwrite': false
    });
  }

  @override
  Future<void> execute() async {
    final sourcePath = source;
    final destinationPath = file.destination;

    emitEvent(StartedEvent(moduleId: action.id, message: 'Starting rename operation'));

    updateState({
      'overwrite': action.properties.containsKey('overwrite') &&
          action.properties['overwrite'] == 'true'
    });

    if (!await FileUtils.fileExists(sourcePath, fileSystem: fileSystem)) {
      logger.severe('Source file $sourcePath does not exist');
      throw SourceNotFoundException(sourcePath);
    }

    await executeModules();
    if (isRollingBack) {
      return;
    }

    final exists = await FileUtils.fileExists(destinationPath, fileSystem: fileSystem);
    updateState({
      'destinationFileExisted': exists,
      'originalName': path.basename(sourcePath)
    });

    emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Renaming $source to $destination'));

    if (exists) {
      emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.warning, message: 'Destination already exists'));
      if (!overwrite) {
        logger.severe(
            'Destination file $destinationPath already exists and overwrite is not allowed');
        throw DestinationExistsException(destinationPath);
      }
    }

    logger.info('Renaming file from $sourcePath to $destinationPath');
    try {
      await FileUtils.moveFile(sourcePath, destinationPath, fileSystem: fileSystem);
      updateState({'renameCompleted': true});
      emitEvent(CompletedEvent(moduleId: action.id, message: 'Rename completed successfully'));
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
    emitEvent(StartedEvent(moduleId: action.id, message: 'Starting rename rollback'));
    try {
      if (originalName != null) {
        final originalPath = path.join(path.dirname(source), originalName!);
        logger.info('Renaming file back from $destination to $originalPath');
        emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Restoring original name'));
        await FileUtils.moveFile(destination, originalPath, fileSystem: fileSystem);
        updateState({'rollbackCompleted': true});
        emitEvent(CompletedEvent(moduleId: action.id, message: 'Rollback completed'));
      }
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
    
    await saveState();
  }
}