import 'package:configr/events/module_events.dart';
import 'package:configr/exceptions.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/file_utils.dart';
import 'package:configr/utils/logging.dart';
import 'package:configr/utils/event_bus.dart';
import 'package:path/path.dart' as path;

class FileCopyModule extends ResourceModule {
  // State getters
  bool get hadToCreateDstDir => state['hadToCreateDstDir'] as bool? ?? false;
  bool get destinationFileExisted => state['destinationFileExisted'] as bool? ?? false;
  String? get originalContent => state['originalContent'] as String?;
  String? get destinationDir => state['destinationDir'] as String?;
  String? get sourceHash => state['sourceHash'] as String?;
  bool get isDirectory => state['isDirectory'] as bool? ?? false;
  bool get recursive => state['recursive'] as bool? ?? false;

  FileCopyModule(super.file, super.action,
      {super.allowedActions = const ['backup'], super.fileSystem}) {
    updateState({
      'hadToCreateDstDir': false,
      'destinationFileExisted': false,
      'originalContent': null,
      'sourceHash': null,
      'destinationDir': null,
      'isDirectory': false,
      'recursive': false,
    });
  }

  @override
  Future<void> execute() async {
    emitEvent(StartedEvent(moduleId: action.id, message: 'Starting copy of $source to $destination'));
    updateState({
      'recursive': action.properties.containsKey('recursive') &&
          action.properties['recursive'] == 'true'
    });

    final existCheck = await FileUtils.pathExists(source, fileSystem: fileSystem);
    if (!existCheck.exists) {
      throw SourceNotFoundException(source);
    }

    updateState({'isDirectory': existCheck.isDir});

    await executeModules();
    if (isRollingBack) {
      return;
    }

    final destDir = isDirectory ? destination : path.dirname(destination);
    updateState({'destinationDir': destDir});

    if (!await FileUtils.directoryExists(destDir, fileSystem: fileSystem)) {
      logger.info('Creating directory $destDir');
      try {
        await FileUtils.createDirectory(destDir, fileSystem: fileSystem);
        updateState({'hadToCreateDstDir': true});
      } catch (e, s) {
        throw ActionFailedException('Failed to create directory $destDir', e, s);
      }
    }

    final exists = await (!isDirectory
        ? FileUtils.fileExists(destination, fileSystem: fileSystem)
        : FileUtils.directoryExists(destination, fileSystem: fileSystem));

    try {
      if (exists) {
        final content = await FileUtils.readFile(destination, fileSystem: fileSystem);
        updateState({
          'destinationFileExisted': true,
          'originalContent': content,
        });
      }

      final hash = await FileUtils.computeFileHash(source, fileSystem: fileSystem);
      updateState({'sourceHash': hash});
    } catch (e, st) {
      logger.warning('Failed to update state', e, st);
    }

    await executeModules();
    if (isRollingBack) {
      return;
    }

    try {
      emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Copying files...'));
      if (isDirectory) {
        await FileUtils.copyDir(source, destination,
            recursive: recursive, fileSystem: fileSystem);
      } else {
        await FileUtils.copyFile(source, destination, fileSystem: fileSystem);
      }
      updateState({'copyCompleted': true});
      emitEvent(CompletedEvent(moduleId: action.id, message: 'Copy completed successfully'));
    } catch (e, st) {
      updateState({
        'error': e.toString(),
        'stackTrace': st.toString()
      });
      emitEvent(FailedEvent(moduleId: action.id, message: 'Copy failed: ${e.toString()}'));
      throw ActionFailedException('Failed to copy', e, st);
    }

    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
    await saveState();
  }

  @override
  Future<void> rollback() async {
    try {
      if (isDirectory) {
        if (await FileUtils.directoryExists(destination, fileSystem: fileSystem)) {
          logger.info('Deleting created directory $destination');
          await FileUtils.deleteDirectory(destination,
              recursive: true, fileSystem: fileSystem);
        }
      } else {
        if (await FileUtils.fileExists(destination, fileSystem: fileSystem)) {
          if (!destinationFileExisted) {
            await FileUtils.deleteFile(destination, fileSystem: fileSystem);
          } else if (originalContent != null) {
            await FileUtils.writeFile(
              destination,
              originalContent!,
              fileSystem: fileSystem,
            );
          }
        }

        if (hadToCreateDstDir && destinationDir != null) {
          if (await FileUtils.directoryExists(destinationDir!)) {
            final contents = await fileSystem!.directory(destinationDir).list().toList();
            if (contents.isEmpty) {
              await FileUtils.deleteDirectory(
                destinationDir!,
                recursive: true,
                fileSystem: fileSystem,
              );
            }
          }
        }
      }
      updateState({'rollbackCompleted': true});
    } catch (e, st) {
      updateState({
        'rollbackError': e.toString(),
        'rollbackStackTrace': st.toString()
      });
      logger.severe('Error during rollback', e, st);
      rethrow;
    }

    for (var module in childModules) {
      await module.rollback();
    }
    
    await saveState();
  }
}