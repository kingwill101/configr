import 'package:configr/exceptions.dart';
import 'package:configr/extensions/string.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/file_utils.dart';
import 'package:configr/utils/logging.dart';
import 'package:path/path.dart';

class FileMoveModule extends ResourceModule {
  bool hadToCreateDstDir = false;
  bool destinationFileExisted = false;
  String? originalPath;

  FileMoveModule(super.file, super.action,
      {super.allowedActions = const ['move'], super.fileSystem});

  @override
  Future<void> call() async {
    final sourcePath = source.clean();
    final destinationPath = file.destination.clean();
    final destinationDir = dirname(destinationPath);

    bool overwrite = action.properties.containsKey('overwrite') &&
        action.properties['overwrite'] == 'true';

    if (!await FileUtils.fileExists(sourcePath, fileSystem: fileSystem)) {
      throw SourceNotFoundException(sourcePath);
    }

    await executeModules();
    if (isRollingBack) {
      return;
    }

    // Check if destination directory exists
    if (!await FileUtils.directoryExists(destinationDir,
        fileSystem: fileSystem)) {
      hadToCreateDstDir = true;

      logger.info('Creating directory $destinationDir');
      try {
        await FileUtils.createDirectory(destinationDir, fileSystem: fileSystem);
      } catch (e, stackTrace) {
        throw ActionFailedException(
            'Failed to create destination directory $destinationDir',
            e,
            stackTrace);
      }
    }

    // Check if destination file exists
    destinationFileExisted =
        await FileUtils.fileExists(destinationPath, fileSystem: fileSystem);

    if (destinationFileExisted && !overwrite) {
      logger.severe(
          'Destination file $destinationPath already exists and overwrite is not allowed');
      throw DestinationExistsException(destinationPath);
    }

    originalPath = sourcePath;
    logger.info('Moving file from $sourcePath to $destinationPath');
    await FileUtils.moveFile(sourcePath, destinationPath,
        fileSystem: fileSystem);

    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
  }

  @override
  Future<void> rollback() async {
    final destinationPath = file.destination.clean();

    if (originalPath != null) {
      logger.info('Moving file back from $destinationPath to $originalPath');
      await FileUtils.moveFile(destinationPath, originalPath!,
          fileSystem: fileSystem);
    }

    if (hadToCreateDstDir) {
      final destinationDir = dirname(destinationPath);
      if (await FileUtils.directoryExists(destinationDir)) {
        logger.info('Deleting created directory $destinationDir');
        await FileUtils.deleteDirectory(destinationDir,
            recursive: true, fileSystem: fileSystem);
      }
    }

    for (var module in childModules) {
      await module.rollback();
    }
  }
}
