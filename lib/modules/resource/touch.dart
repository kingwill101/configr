import 'package:configr/events/module_events.dart';
import 'package:configr/exceptions.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/file_utils.dart';
import 'package:configr/utils/logging.dart';
import 'package:configr/utils/event_bus.dart';

class FileTouchModule extends ResourceModule {
  // State getters
  DateTime? get originalModificationTime => 
      state['originalModificationTime'] != null 
          ? DateTime.parse(state['originalModificationTime'] as String) 
          : null;
  bool get fileCreated => state['fileCreated'] as bool? ?? false;
  bool get createIfMissing => state['createIfMissing'] as bool? ?? false;

  FileTouchModule(super.file, super.action,
      {super.allowedActions = const ['touch'], super.fileSystem}) {
    updateState({
      'originalModificationTime': null,
      'fileCreated': false,
      'createIfMissing': false
    });
  }

  @override
  Future<void> execute() async {
    emitEvent(StartedEvent(moduleId: action.id, message: 'Starting touch operation'));
    final destinationPath = file.destination;
    updateState({
      'createIfMissing': action.properties['create_if_missing'] == 'true'
    });

    await executeModules();
    if (isRollingBack) {
      return;
    }

    final fileExists = await FileUtils.fileExists(destinationPath, fileSystem: fileSystem);

    if (!fileExists && !createIfMissing) {
      logger.severe('File $destinationPath does not exist and create_if_missing is false');
      throw SourceNotFoundException(destinationPath);
    }

    try {
      if (fileExists) {
        final file = fileSystem!.file(destinationPath);
        final modTime = await file.lastModified();
        updateState({
          'originalModificationTime': modTime.toIso8601String()
        });
      } else {
        emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Creating new file'));
        updateState({'fileCreated': true});
      }

      final file = fileSystem!.file(destinationPath);
      await file.create(recursive: true);
      await file.setLastModified(DateTime.now());
      emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Touching file: $destination'));
      logger.info('Touched file: $destinationPath');
      updateState({'touchCompleted': true});
    } catch (e, st) {
      updateState({
        'error': e.toString(),
        'stackTrace': st.toString()
      });
      throw ActionFailedException('Error touching file $destinationPath', e);
    }

    emitEvent(CompletedEvent(moduleId: action.id, message: 'Touch operation completed'));
    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
    await saveState();
  }

  @override
  Future<void> rollback() async {
    emitEvent(StartedEvent(moduleId: action.id, message: 'Rolling back touch operation'));
    try {
      if (fileCreated) {
        emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Removing created file'));
        logger.info('Deleting created file: $destination');
        await FileUtils.deleteFile(destination, fileSystem: fileSystem);
      } else if (originalModificationTime != null) {
        logger.info('Restoring original modification time for: $destination');
        final file = fileSystem!.file(destination);
        await file.setLastModified(originalModificationTime!);
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