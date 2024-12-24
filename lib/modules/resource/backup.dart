import 'package:configr/exceptions.dart';
import 'package:configr/extensions/map.dart';
import 'package:configr/extensions/string.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/file_utils.dart';
import 'package:configr/utils/logging.dart';
import 'package:path/path.dart';

class FileBackupModule extends ResourceModule {
  bool hadToCreateDstDir = false;
  bool destinationFileExisted = false;
  String? backupPath;

  FileBackupModule(super.file, super.action, {super.fileSystem});

  @override
  Future<void> call() async {
    final props = action.properties.requires(['backup_path']);
    final String destination = (props['backup_path'] as String).clean();

    final destinationDir = dirname(destination);

    if (!isDir) {
      if (!await FileUtils.fileExists(source, fileSystem: fileSystem)) {
        throw SourceNotFoundException(source);
      }
    } else {
      if (!await FileUtils.directoryExists(source, fileSystem: fileSystem)) {
        throw SourceNotFoundException(source);
      }
    }

    // Check if destination directory exists
    if (!await FileUtils.directoryExists(destinationDir,
        fileSystem: fileSystem)) {
      hadToCreateDstDir = true;
      logger.info('Creating directory $destinationDir');
      try {
        await FileUtils.createDirectory(destinationDir, fileSystem: fileSystem);
      } catch (e) {
        throw ActionFailedException(
            'Failed to create directory $destinationDir');
      }
    }

    // Check if destination file exists
    destinationFileExisted =
        await FileUtils.fileExists(destination, fileSystem: fileSystem);

    if (!destinationFileExisted) {
      // Backup the existing destination file
      try {
        bool recursive = action.properties.containsKey('recursive') &&
            action.properties['recursive'] == 'true';

        if (isDir) {
          logger.info('Backing up dir $source -> $destination');

          await FileUtils.copyDir(source, destination,
              recursive: recursive, fileSystem: fileSystem);
        } else {
          logger.info('Backing up file $source -> $destination');

          await FileUtils.copyFile(source, destination, fileSystem: fileSystem);
        }
      } catch (e, stackTrace) {
        throw ActionFailedException(
            'Failed to backup file $source', e, stackTrace);
      }
    } else {
      logger.warning(
          'Destination file $destination already exists, skipping backup');
    }

    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
  }

  @override
  Future<void> rollback() async {
    final props = action.properties.requires(['backup_path']);
    final String destination = (props['backup_path'] as String).clean();

    if (!destinationFileExisted) {
      if (isDir) {
        if (await FileUtils.directoryExists(destination,
            fileSystem: fileSystem)) {
          logger.info('Deleting directory backup $destination');
          await FileUtils.deleteDirectory(destination,
              recursive: true, fileSystem: fileSystem);
        } else {
          logger.warning(
              'Directory $destination does not exist, skipping deletion');
        }
      } else {
        // Delete the copied file
        if (await FileUtils.fileExists(destination, fileSystem: fileSystem)) {
          logger.info('Deleting file backup $destination');
          await FileUtils.deleteFile(destination, fileSystem: fileSystem);
        }
      }
    }

    if (hadToCreateDstDir) {
      // Remove the created destination directory if it's empty
      final destinationDir = dirname(destination);
      if (await FileUtils.directoryExists(destinationDir,
          fileSystem: fileSystem)) {
        try {
          final dirContents =
              await fileSystem!.directory(destinationDir).list().toList();
          if (dirContents.isEmpty) {
            logger.info('Removing created empty directory $destinationDir');
            await FileUtils.deleteDirectory(destinationDir,
                fileSystem: fileSystem);
          } else {
            logger
                .info('Directory $destinationDir not empty, skipping removal');
          }
        } catch (e) {
          throw ActionFailedException(
              'Failed to check/remove directory $destinationDir', e);
        }
      }
    }
  }
}
