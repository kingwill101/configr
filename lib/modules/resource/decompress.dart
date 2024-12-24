import 'package:configr/exceptions.dart';
import 'package:configr/extensions/string.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/file_utils.dart';
import 'package:configr/utils/logging.dart';
import 'package:archive/archive.dart';

class FileDecompressModule extends ResourceModule {
  List<String> createdFiles = [];

  FileDecompressModule(super.file, super.action,
      {super.allowedActions = const ['decompress'], super.fileSystem});

  @override
  Future<void> call() async {
    final String format = (action.properties.containsKey("format")
            ? action.properties['format'] as String
            : 'zip')
        .unquote()
        .unescape();

    if (!await FileUtils.fileExists(source, fileSystem: fileSystem)) {
      logger.severe('Source archive $source does not exist');
      throw SourceNotFoundException(source);
    }

    await executeModules();
    if (isRollingBack) {
      return;
    }

    logger.info('Decompressing $source to $destination');
    try {
      final compressedData =
          await FileUtils.readFile(source, fileSystem: fileSystem);
      List<int> data = compressedData.codeUnits;

      Archive archive;
      if (format == 'zip') {
        archive = ZipDecoder().decodeBytes(data);
      } else if (format == 'tar.gz') {
        final gzipData = GZipDecoder().decodeBytes(data);
        archive = TarDecoder().decodeBytes(gzipData);
      } else {
        throw Exception('Unsupported compression format: $format');
      }

      for (final file in archive) {
        final filePath = fileSystem!.path.join(destination, file.name);
        if (file.isFile) {
          logger.info('Decompressing file $filePath');
          await FileUtils.writeFile(
              recursive: true,
              filePath,
              String.fromCharCodes(file.content),
              fileSystem: fileSystem);
          createdFiles.add(filePath);
        } else {
          await FileUtils.createDirectory(filePath, fileSystem: fileSystem);
        }
      }
    } catch (e, s) {
      throw ActionFailedException('Failed to decompress file $source', e, s);
    }

    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
  }

  @override
  Future<void> rollback() async {
    for (final filePath in createdFiles.reversed) {
      logger.info('Deleting decompressed file $filePath');
      await FileUtils.deleteFile(filePath, fileSystem: fileSystem);
    }

    for (var module in childModules) {
      await module.rollback();
    }
  }
}
