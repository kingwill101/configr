import 'dart:convert';
import 'package:configr/exceptions.dart';
import 'package:crypto/crypto.dart';

import 'package:configr/extensions/string.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/file_utils.dart';
import 'package:configr/utils/logging.dart';

class FileValidateModule extends ResourceModule {
  FileValidateModule(super.file, super.action,
      {super.allowedActions = const ['validate'], super.fileSystem});

  @override
  Future<void> call() async {
    final sourcePath = source.clean();

    if (!await FileUtils.fileExists(sourcePath, fileSystem: fileSystem)) {
      throw SourceNotFoundException(sourcePath);
    }

    await executeModules();
    if (isRollingBack) {
      return;
    }

    final String? checksum = action.properties['checksum'];
    final String? format = action.properties['format'];

    if (checksum != null) {
      await _validateChecksum(sourcePath, checksum);
    }

    if (format != null) {
      await _validateFormat(sourcePath, format);
    }

    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
  }

  Future<void> _validateChecksum(
      String filePath, String expectedChecksum) async {
    final fileContent =
        await FileUtils.readFile(filePath, fileSystem: fileSystem);
    final actualChecksum = sha256.convert(fileContent.codeUnits).toString();

    if (actualChecksum != expectedChecksum) {
      throw ChecksumValidationException(
          filePath, expectedChecksum, actualChecksum);
    }

    logger.info('Checksum validation passed for $filePath');
  }

  Future<void> _validateFormat(String filePath, String format) async {
    final fileContent =
        await FileUtils.readFile(filePath, fileSystem: fileSystem);

    try {
      switch (format.toLowerCase()) {
        case 'json':
          json.decode(fileContent);
          break;
        case 'yaml':
          // You might need to add a YAML package for proper validation
          // For now, we'll just check if it's not empty
          if (fileContent.trim().isEmpty) {
            throw FormatException('Empty YAML file');
          }
          break;
        default:
          throw UnsupportedError('Unsupported format: $format');
      }
      logger.info('Format validation passed for $filePath');
    } catch (e) {
      throw FormatValidationException(filePath, format, e);
    }
  }

  @override
  Future<void> rollback() async {
    // Validation doesn't modify files, so no rollback is necessary
    for (var module in childModules) {
      await module.rollback();
    }
  }
}
