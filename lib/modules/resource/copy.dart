import 'package:configr/exceptions.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/file_utils.dart';
import 'package:configr/utils/logging.dart';
import 'package:path/path.dart' as path;

class FileCopyModule extends ResourceModule {
  bool hadToCreateDstDir = false;
  bool destinationFileExisted = false;

  FileCopyModule(super.file, super.action,
      {super.allowedActions = const ['backup'], super.fileSystem});

  @override
  Future<void> call() async {
    bool recursive = action.properties.containsKey('recursive') &&
        action.properties['recursive'] == 'true';

    if (!isDir) {
      if (!await FileUtils.fileExists(source, fileSystem: fileSystem)) {
        throw SourceNotFoundException(source);
      }
    } else {
      if (!await FileUtils.directoryExists(source, fileSystem: fileSystem)) {
        throw SourceNotFoundException(source);
      }
    }

    await executeModules();
    if (isRollingBack) {
      return;
    }

    final destinationDir = isDir ? destination : path.dirname(destination);
    // Check if destination directory exists
    if (!await FileUtils.directoryExists(destinationDir,
        fileSystem: fileSystem)) {
      hadToCreateDstDir = true;

      // await dialog(
      //   "Directory $destination does not exist. Should we create it?",
      //   defaultValue: true,
      //   onReject: () {
      //     logger.severe('Destination path is not a directory');
      //     exit(-1);
      //   },
      //   onAccept: () async {
      logger.info('Creating directory $destination');
      try {
        await FileUtils.createDirectory(destinationDir, fileSystem: fileSystem);
      } catch (e, s) {
        throw ActionFailedException(
            'Failed to create directory $destination', e, s);
      }
      // },
      // );
    }
    // Check if destination file exists
    destinationFileExisted = await (!isDir
        ? FileUtils.fileExists(destination, fileSystem: fileSystem)
        : FileUtils.directoryExists(destination, fileSystem: fileSystem));

    if (isDir) {
      await FileUtils.copyDir(source, destination,
          recursive: recursive, fileSystem: fileSystem);
    } else {
      await FileUtils.copyFile(source, destination, fileSystem: fileSystem);
    }
    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
  }

  @override
  Future<void> rollback() async {
    if (isDir) {
      if (await FileUtils.directoryExists(destination,
          fileSystem: fileSystem)) {
        logger.info('Deleting created directory $destination');
        await FileUtils.deleteDirectory(destination,
            recursive: true, fileSystem: fileSystem);
      } else {
        logger.warning(
            'Directory $destination does not exist, skipping deletion');
      }
    } else {
      // Delete the copied file
      if (await FileUtils.fileExists(destination, fileSystem: fileSystem)) {
        logger.info('Deleting copied file $destination');
        await FileUtils.deleteFile(destination, fileSystem: fileSystem);
      }
    }

    // Delete the destination directory if it was created
    if (hadToCreateDstDir) {
      // Check if directory is empty before deleting
      if (await FileUtils.directoryExists(destination)) {
        logger.info('Deleting created directory $destination');
        await FileUtils.deleteDirectory(destination,
            recursive: true, fileSystem: fileSystem);
      } else {
        logger
            .warning('Directory $destination is not empty. Skipping deletion.');
      }
    }
    for (var module in childModules) {
      module.rollback();
    }
  }
}
