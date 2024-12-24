import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/file_utils.dart';
import 'package:configr/utils/logging.dart';

class FileDeleteModule extends ResourceModule {
  String? backupPath;
  bool fileExisted = false;

  FileDeleteModule(super.file, super.action,
      {super.allowedActions = const ['delete'], super.fileSystem});

  @override
  Future<void> call() async {
    final sourcePath = source;

    if (!await FileUtils.fileExists(sourcePath, fileSystem: fileSystem)) {
      logger.warning('File $sourcePath does not exist, skipping deletion');
      return;
    }

    fileExisted = true;

    await executeModules();
    if (isRollingBack) {
      return;
    }

    if (action.properties.containsKey('backup')) {
      backupPath = action.properties['backup']['backup_path'];
      logger.info('Backing up file $sourcePath to $backupPath');
      await FileUtils.copyFile(sourcePath, backupPath!, fileSystem: fileSystem);
    }

    logger.info('Deleting file $sourcePath');
    await FileUtils.deleteFile(sourcePath, fileSystem: fileSystem);

    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
  }

  @override
  Future<void> rollback() async {
    final sourcePath = source;

    if (fileExisted && backupPath != null) {
      logger.info('Restoring file from $backupPath to $sourcePath');
      await FileUtils.copyFile(backupPath!, sourcePath, fileSystem: fileSystem);
      await FileUtils.deleteFile(backupPath!, fileSystem: fileSystem);
    }

    for (var module in childModules) {
      await module.rollback();
    }
  }
}
