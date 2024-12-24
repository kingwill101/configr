import 'dart:io';

import 'package:configr/extensions/string.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/file_utils.dart';
import 'package:configr/utils/logging.dart';
import 'package:path/path.dart' as path;

class FileRenameModule extends ResourceModule {
  String? originalName;
  bool destinationFileExisted = false;

  FileRenameModule(super.file, super.action,
      {super.allowedActions = const ['rename'], super.fileSystem});

  @override
  Future<void> call() async {
    final sourcePath = source.clean();
    final destinationPath = file.destination.clean();

    bool overwrite = action.properties.containsKey('overwrite') &&
        action.properties['overwrite'] == 'true';

    if (!await FileUtils.fileExists(sourcePath, fileSystem: fileSystem)) {
      logger.severe('Source file $sourcePath does not exist');
      exit(-1);
    }

    await executeModules();
    if (isRollingBack) {
      return;
    }

    destinationFileExisted =
        await FileUtils.fileExists(destinationPath, fileSystem: fileSystem);

    if (destinationFileExisted && !overwrite) {
      logger.severe(
          'Destination file $destinationPath already exists and overwrite is not allowed');
      exit(-1);
    }

    originalName = path.basename(sourcePath);
    logger.info('Renaming file from $sourcePath to $destinationPath');
    await FileUtils.moveFile(sourcePath, destinationPath,
        fileSystem: fileSystem);

    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
  }

  @override
  Future<void> rollback() async {
    final sourcePath = source.clean();
    final destinationPath = file.destination.clean();

    if (originalName != null) {
      final originalPath = path.join(path.dirname(sourcePath), originalName!);
      logger.info('Renaming file back from $destinationPath to $originalPath');
      await FileUtils.moveFile(destinationPath, originalPath,
          fileSystem: fileSystem);
    }

    for (var module in childModules) {
      await module.rollback();
    }
  }
}
