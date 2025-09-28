import 'package:configr/events/module_events.dart';
import 'package:configr/exceptions.dart';
import 'package:configr/extensions/map.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/event_bus.dart';
import 'package:configr/utils/file_utils.dart';
import 'package:configr/utils/logging.dart';
import 'package:path/path.dart';

class FileBackupModule extends ResourceModule {
  // State getters
  bool get hadToCreateDstDir => state['hadToCreateDstDir'] as bool? ?? false;

  bool get destinationFileExisted =>
      state['destinationFileExisted'] as bool? ?? false;

  String? get backupPath => state['backupPath'] as String?;

  bool get isDirectory => state['isDirectory'] as bool? ?? false;

  FileBackupModule(super.file, super.action, {super.fileSystem});

  @override
  Future<void> execute() async {
    final props = action.properties.requires(['backup_path']);
    final String destination = (props['backup_path'] as String);
    emitEvent(StartedEvent(
        moduleId: action.id,
        message: 'Starting backup of $source to $destination'));
    updateState({'backupPath': destination});

    final destinationDir = dirname(destination);
    final existCheck =
        await FileUtils.pathExists(source, fileSystem: fileSystem);

    if (!existCheck.exists) {
      throw SourceNotFoundException(source);
    }

    updateState({'isDirectory': existCheck.isDir});

    if (!await FileUtils.directoryExists(destinationDir,
        fileSystem: fileSystem)) {
      logger.info('Creating directory $destinationDir');
      emitEvent(StatusUpdateEvent(
          moduleId: action.id,
          level: StatusEvent.info,
          message: 'Creating directory $destinationDir'));
      try {
        await FileUtils.createDirectory(destinationDir, fileSystem: fileSystem);
        updateState({'hadToCreateDstDir': true});
      } catch (e) {
        emitEvent(FailedEvent(
            moduleId: action.id,
            message: 'Failed to create directory $destinationDir'));
        throw ActionFailedException(
            'Failed to create directory $destinationDir');
      }
    }

    final destExists =
        await FileUtils.fileExists(destination, fileSystem: fileSystem);
    updateState({'destinationFileExisted': destExists});

    if (!destExists) {
      try {
        bool recursive = action.properties.containsKey('recursive') &&
            action.properties['recursive'] == 'true';

        emitEvent(StatusUpdateEvent(
            moduleId: action.id,
            level: StatusEvent.info,
            message: 'Creating backup...'));
        if (isDirectory) {
          logger.info('Backing up dir $source -> $destination');
          emitEvent(StatusUpdateEvent(
              moduleId: action.id,
              level: StatusEvent.info,
              message: 'Backing up directory $source -> $destination'));
          await FileUtils.copyDir(source, destination,
              recursive: recursive, fileSystem: fileSystem);
        } else {
          logger.info('Backing up file $source -> $destination');
          emitEvent(StatusUpdateEvent(
              moduleId: action.id,
              level: StatusEvent.info,
              message: 'Backing up file $source -> $destination'));
          await FileUtils.copyFile(source, destination, fileSystem: fileSystem);
        }
        updateState({'backupCompleted': true});
        emitEvent(CompletedEvent(
            moduleId: action.id, message: 'Backup completed successfully'));
      } catch (e, stackTrace) {
        updateState(
            {'error': e.toString(), 'stackTrace': stackTrace.toString()});
        emitEvent(FailedEvent(
            moduleId: action.id, message: 'Backup failed: ${e.toString()}'));
        throw ActionFailedException(
            'Failed to backup file $source', e, stackTrace);
      }
    } else {
      emitEvent(StatusUpdateEvent(
          moduleId: action.id,
          level: StatusEvent.warning,
          message:
              'Destination file $destination already exists, skipping backup'));
      logger.warning(
          'Destination file $destination already exists, skipping backup');
    }

    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
    await saveState();
  }

  @override
  Future<void> rollback() async {
    emitEvent(StartedEvent(
        moduleId: action.id, message: 'Starting rollback of backup'));
    if (!destinationFileExisted) {
      if (isDirectory) {
        if (await FileUtils.directoryExists(backupPath!,
            fileSystem: fileSystem)) {
          logger.info('Deleting directory backup $backupPath');
          emitEvent(StatusUpdateEvent(
              moduleId: action.id,
              level: StatusEvent.info,
              message: 'Deleting directory backup $backupPath'));
          await FileUtils.deleteDirectory(backupPath!,
              recursive: true, fileSystem: fileSystem);
        }
      } else {
        if (await FileUtils.fileExists(backupPath!, fileSystem: fileSystem)) {
          logger.info('Deleting file backup $backupPath');
          emitEvent(StatusUpdateEvent(
              moduleId: action.id,
              level: StatusEvent.info,
              message: 'Deleting file backup $backupPath'));
          await FileUtils.deleteFile(backupPath!, fileSystem: fileSystem);
        }
      }
    }

    if (hadToCreateDstDir) {
      final destinationDir = dirname(backupPath!);
      if (await FileUtils.directoryExists(destinationDir,
          fileSystem: fileSystem)) {
        try {
          final dirContents =
              await fileSystem!.directory(destinationDir).list().toList();
          if (dirContents.isEmpty) {
            logger.info('Removing created empty directory $destinationDir');
            emitEvent(StatusUpdateEvent(
                moduleId: action.id,
                level: StatusEvent.info,
                message: 'Removing created empty directory $destinationDir'));
            await FileUtils.deleteDirectory(destinationDir,
                fileSystem: fileSystem);
          }
        } catch (e) {
          emitEvent(FailedEvent(
              moduleId: action.id,
              message: 'Failed to check/remove directory $destinationDir'));

          throw ActionFailedException(
              'Failed to check/remove directory $destinationDir', e);
        }
      }
    }

    emitEvent(CompletedEvent(
        moduleId: action.id, message: 'Rollback completed successfully'));
    updateState({'rollbackCompleted': true});
    await saveState();
  }
}
