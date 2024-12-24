import 'package:configr/exceptions.dart';
import 'package:configr/extensions/map.dart';
import 'package:configr/extensions/string.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/file_utils.dart';
import 'package:configr/utils/logging.dart';
import 'package:path/path.dart';

class FileSymlinkModule extends ResourceModule {
  bool hadToCreateDstDir = false;
  bool symlinkExisted = false;
  String? originalTarget;

  FileSymlinkModule(super.file, super.action,
      {super.allowedActions = const ['symlink'], super.fileSystem});

  @override
  Future<void> call() async {
    final sourcePath = absolute(source);
    action.properties.requires(['link_path']);
    final symlinkPath = (action.properties['link_path'] as String).clean();
    final symlinkDir = dirname(symlinkPath);

    if (!await FileUtils.fileExists(sourcePath, fileSystem: fileSystem)) {
      throw SourceNotFoundException(sourcePath);
    }

    executeModules();
    if (isRollingBack) {
      return;
    }

    // Check if symlink directory exists
    if (!await FileUtils.directoryExists(symlinkDir, fileSystem: fileSystem)) {
      // hadToCreateDstDir = true;
      // logger.info('Creating symlink directory $symlinkDir');
      // await dialog(
      //   "Directory $symlinkDir does not exist. Should we create it?",
      //   defaultValue: true,
      //   onReject: () {
      //     logger.severe('Symlink path is not a directory');
      //     exit(-1);
      //   },
      //   onAccept: () async {
      logger.info('Creating directory $symlinkDir');
      await FileUtils.createDirectory(symlinkDir, fileSystem: fileSystem);
      //     print("-0-----");
      //   },
      // );
    }

    // Check if symlink already exists
    if (await FileUtils.isSymlink(symlinkPath, fileSystem: fileSystem)) {
      symlinkExisted = true;
      originalTarget =
          await FileUtils.readSymlink(symlinkPath, fileSystem: fileSystem);
      logger.info(
          'Symlink $symlinkPath already exists and points to $originalTarget');
    } else {
      logger.info('Creating symlink from $sourcePath to $symlinkPath');
      try {
        await FileUtils.createSymlink(sourcePath, symlinkPath,
            fileSystem: fileSystem);
      } catch (e) {
        throw SymlinkCreationException(symlinkPath, e);
      }
    }

    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
  }

  @override
  Future<void> rollback() async {
    final symlinkPath = file.destination.clean();
    final symlinkDir = dirname(symlinkPath);

    // Remove the symlink
    if (await FileUtils.isSymlink(symlinkPath, fileSystem: fileSystem)) {
      logger.info('Deleting symlink $symlinkPath');
      await FileUtils.deleteFile(symlinkPath, fileSystem: fileSystem);
    }

    // Restore the original symlink if it existed
    if (symlinkExisted && originalTarget != null) {
      logger.info(
          'Restoring original symlink $symlinkPath to point to $originalTarget');
      try {
        await FileUtils.createSymlink(originalTarget!, symlinkPath,
            fileSystem: fileSystem);
      } catch (e) {
        throw ActionFailedException(
            'Failed to restore original symlink $symlinkPath');
      }
    }

    // Delete the destination directory if it was created
    if (hadToCreateDstDir) {
      if (await FileUtils.directoryExists(symlinkDir)) {
        logger.info('Deleting created directory $symlinkDir');
        await FileUtils.deleteDirectory(symlinkDir,
            recursive: true, fileSystem: fileSystem);
      } else {
        logger
            .warning('Directory $symlinkDir is not empty. Skipping deletion.');
      }
    }

    for (var module in childModules) {
      await module.rollback();
    }
  }
}
