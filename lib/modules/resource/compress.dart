import 'dart:io';
import 'package:configr/events/module_events.dart';
import 'package:configr/exceptions.dart';
import 'package:configr/extensions/string.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/file_utils.dart';
import 'package:configr/utils/fs.dart';
import 'package:configr/utils/logging.dart';
import 'package:archive/archive.dart';
import 'package:configr/utils/event_bus.dart';

class FileCompressModule extends ResourceModule {
  // State getters
  bool get destinationFileExisted => state['destinationFileExisted'] as bool? ?? false;
  String get format => state['format'] as String? ?? 'zip';
  bool get recursive => state['recursive'] as bool? ?? false;

  FileCompressModule(super.file, super.action,
      {super.allowedActions = const ['compress'], super.fileSystem});

  @override
  Future<void> execute() async {
    emitEvent(StartedEvent(moduleId: action.id, message: 'Starting compression of $source'));
    // Initialize state
    updateState({
      'format': (action.properties.containsKey("format") 
          ? action.properties['format'] as String 
          : 'zip').unquote().unescape(),
      'recursive': action.properties.containsKey('recursive') &&
          action.properties['recursive'] == 'true',
    });

    final pathExists = await FileUtils.pathExists(source, fileSystem: fileSystem ?? fs);
    if (!pathExists.exists) {
      throw SourceNotFoundException(source);
    }

    await executeModules();
    if (isRollingBack) {
      return;
    }

    final fileExists = await FileUtils.fileExists(destination, fileSystem: fileSystem);
    updateState({'destinationFileExisted': fileExists});

    logger.info('Compressing $source to $destination');
    try {
      emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Compressing files...'));
      final archive = Archive();
      if (pathExists.isDir) {
        await _addDirectoryToArchive(source, archive, recursive: recursive);
      } else {
        final fileContent = await FileUtils.readFile(source, fileSystem: fileSystem);
        archive.addFile(ArchiveFile(source, fileContent.length, fileContent.codeUnits));
      }

      List<int> compressedData;
      if (format == "zip") {
        compressedData = ZipEncoder().encode(archive);
      } else if (format == 'tar.gz') {
        final tarData = TarEncoder().encode(archive);
        compressedData = GZipEncoder().encode(tarData);
      } else {
        throw Exception('Unsupported compression format: $format');
      }

      if (await FileUtils.fileExists(destination, fileSystem: fileSystem)) {
        logger.info('Deleting existing compressed file $destination');
        await FileUtils.deleteFile(destination, fileSystem: fileSystem);
      }

      await FileUtils.writeFile(
          recursive: true,
          destination,
          String.fromCharCodes(compressedData),
          fileSystem: fileSystem);
      logger.info('Compressed file $destination');

      updateState({'compressionCompleted': true});
      emitEvent(CompletedEvent(moduleId: action.id, message: 'Compression completed successfully'));
    } catch (e, s) {
      updateState({'error': e.toString(), 'stackTrace': s.toString()});
      emitEvent(FailedEvent(moduleId: action.id, message: 'Compression failed: ${e.toString()}'));
      throw ActionFailedException('Failed to compress file $destination', e, s);
    }

    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
    await saveState();
  }

  Future<void> _addDirectoryToArchive(String dirPath, Archive archive,
      {bool recursive = false}) async {
    final dir = fileSystem!.directory(dirPath);
    await for (final entity in dir.list(recursive: recursive)) {
      if (entity is File) {
        final relativePath = fileSystem!.path.relative(entity.path, from: dirPath);
        final fileContent = (entity as File).readAsBytesSync();
        archive.addFile(ArchiveFile(relativePath, fileContent.length, fileContent));
      }
    }
  }

  @override
  Future<void> rollback() async {
    if (!destinationFileExisted) {
      logger.info('Deleting compressed file $destination');
      await FileUtils.deleteFile(destination, fileSystem: fileSystem);
      updateState({'rollbackCompleted': true});
    }

    for (var module in childModules) {
      await module.rollback();
    }
    
    await saveState();
  }
}