import 'package:configr/events/module_events.dart';
import 'package:configr/exceptions.dart';
import 'package:configr/extensions/string.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/file_utils.dart';
import 'package:configr/utils/logging.dart';
import 'package:archive/archive.dart';
import 'package:configr/utils/event_bus.dart';

class FileDecompressModule extends ResourceModule {
  // State getters
  List<String> get createdFiles {
    // First check module state, then fall back to action state for rollback
    final moduleFiles = (state['createdFiles'] as List<dynamic>? ?? [])
        .cast<String>();
    if (moduleFiles.isNotEmpty) {
      return moduleFiles;
    }

    // For rollback, check action state
    final actionFiles = (action.state['createdFiles'] as List<dynamic>? ?? [])
        .cast<String>();
    return actionFiles;
  }

  String get format => state['format'] as String? ?? 'zip';
  bool get sourceExists => state['sourceExists'] as bool? ?? false;

  FileDecompressModule(
    super.file,
    super.action, {
    super.allowedActions = const ['decompress'],
    super.fileSystem,
  }) {
    updateState({'createdFiles': [], 'sourceExists': false, 'format': 'zip'});
  }

  @override
  Future<void> execute() async {
    emitEvent(
      StartedEvent(
        moduleId: action.id,
        message: 'Starting decompression of $source',
      ),
    );

    updateState({
      'format':
          (action.properties.containsKey("format")
                  ? action.properties['format'] as String
                  : 'zip')
              .unquote()
              .unescape(),
    });

    final exists = await FileUtils.fileExists(source, fileSystem: fileSystem);
    updateState({'sourceExists': exists});

    if (!exists) {
      logger.severe('Source archive $source does not exist');
      throw SourceNotFoundException(source);
    }

    await executeModules();
    if (isRollingBack) {
      return;
    }

    logger.info('Decompressing $source to $destination');
    try {
      emitEvent(
        StatusUpdateEvent(
          moduleId: action.id,
          level: StatusEvent.info,
          message: 'Decompressing files...',
        ),
      );

      final data = await FileUtils.readBinaryFile(
        source,
        fileSystem: fileSystem,
      );

      Archive archive;
      if (format == 'zip') {
        archive = ZipDecoder().decodeBytes(data);
      } else if (format == 'tar.gz') {
        final gzipData = GZipDecoder().decodeBytes(data);
        archive = TarDecoder().decodeBytes(gzipData);
      } else {
        throw Exception('Unsupported compression format: $format');
      }

      List<String> newFiles = [];
      for (final file in archive) {
        final filePath = fileSystem!.path.join(destination, file.name);
        if (file.isFile) {
          logger.info('Decompressing file $filePath');
          await FileUtils.writeFile(
            recursive: true,
            filePath,
            String.fromCharCodes(file.content),
            fileSystem: fileSystem,
          );
          newFiles.add(filePath);
        } else {
          await FileUtils.createDirectory(filePath, fileSystem: fileSystem);
        }
      }

      updateState({'createdFiles': newFiles, 'decompressionCompleted': true});

      emitEvent(
        CompletedEvent(
          moduleId: action.id,
          message: 'Decompression completed successfully',
        ),
      );
    } catch (e, s) {
      updateState({'error': e.toString(), 'stackTrace': s.toString()});
      emitEvent(
        FailedEvent(
          moduleId: action.id,
          message: 'Decompression failed: ${e.toString()}',
        ),
      );
      throw ActionFailedException('Failed to decompress file $source', e, s);
    }

    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
    await saveState();
  }

  @override
  Future<void> rollback() async {
    try {
      // Instead of deleting individual files, remove the entire destination directory
      if (await FileUtils.directoryExists(
        destination,
        fileSystem: fileSystem,
      )) {
        logger.info(
          'Removing decompression directory $destination recursively',
        );
        await FileUtils.deleteDirectory(
          destination,
          fileSystem: fileSystem,
          recursive: true,
        );
      } else {
        logger.info(
          'Decompression directory $destination does not exist, skipping cleanup',
        );
      }
      updateState({'rollbackCompleted': true});
    } catch (e, st) {
      updateState({
        'rollbackError': e.toString(),
        'rollbackStackTrace': st.toString(),
      });
      rethrow;
    }

    for (var module in childModules) {
      await module.rollback();
    }

    await saveState();
  }
}
