import 'dart:io';

import 'package:configr/exceptions.dart';
import 'package:configr/extensions/string.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/file_utils.dart';
import 'package:configr/utils/logging.dart';

class FileTouchModule extends ResourceModule {
  DateTime? originalModificationTime;
  bool fileCreated = false;

  FileTouchModule(super.file, super.action,
      {super.allowedActions = const ['touch'], super.fileSystem});

  @override
  Future<void> call() async {
    final destinationPath = file.destination.clean();
    final createIfMissing = action.properties['create_if_missing'] == 'true';

    await executeModules();
    if (isRollingBack) {
      return;
    }

    final fileExists =
        await FileUtils.fileExists(destinationPath, fileSystem: fileSystem);

    if (!fileExists && !createIfMissing) {
      logger.severe(
          'File $destinationPath does not exist and create_if_missing is false');
      throw SourceNotFoundException(destinationPath);
    }

    if (fileExists) {
      final file = fileSystem!.file(destinationPath);
      originalModificationTime = await file.lastModified();
    } else {
      fileCreated = true;
    }

    try {
      final file = fileSystem!.file(destinationPath);
      await file.create(recursive: true);
      await file.setLastModified(DateTime.now());
      logger.info('Touched file: $destinationPath');
    } catch (e) {
      throw ActionFailedException('Error touching file $destinationPath', e);
    }

    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
  }

  @override
  Future<void> rollback() async {
    final destinationPath = file.destination.clean();

    if (fileCreated) {
      logger.info('Deleting created file: $destinationPath');
      await FileUtils.deleteFile(destinationPath, fileSystem: fileSystem);
    } else if (originalModificationTime != null) {
      logger.info('Restoring original modification time for: $destinationPath');
      final file = fileSystem!.file(destinationPath);
      await file.setLastModified(originalModificationTime!);
    }

    for (var module in childModules) {
      await module.rollback();
    }
  }
}
