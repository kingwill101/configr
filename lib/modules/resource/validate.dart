import 'dart:convert';
import 'package:configr/events/module_events.dart';
import 'package:configr/exceptions.dart';
import 'package:crypto/crypto.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/file_utils.dart';
import 'package:configr/utils/logging.dart';
import 'package:configr/utils/event_bus.dart';

class FileValidateModule extends ResourceModule {
  // State getters
  String? get checksum => state['checksum'] as String?;
  String? get format => state['format'] as String?;
  String? get actualChecksum => state['actualChecksum'] as String?;
  bool get sourceExists => state['sourceExists'] as bool? ?? false;

  FileValidateModule(super.file, super.action,
      {super.allowedActions = const ['validate'], super.fileSystem}) {
    updateState({
      'checksum': action.properties['checksum'],
      'format': action.properties['format'],
      'actualChecksum': null,
      'sourceExists': false
    });
  }

  @override
  Future<void> execute() async {
    emitEvent(StartedEvent(moduleId: action.id, message: 'Starting file validation'));
    final sourcePath = source;
    final exists =
        await FileUtils.fileExists(sourcePath, fileSystem: fileSystem);
    updateState({'sourceExists': exists});

    if (!exists) {
      throw SourceNotFoundException(sourcePath);
    }

    await executeModules();
    if (isRollingBack) {
      return;
    }

    try {
      if (checksum != null) {
        emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Validating checksum'));
        emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Expected checksum: $checksum'));
        await _validateChecksum(sourcePath, checksum!);
      }

      if (format != null) {
        emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Validating format: $format'));
        await _validateFormat(sourcePath, format!);
      }

      updateState({'validationCompleted': true});
      emitEvent(CompletedEvent(moduleId: action.id, message: 'Validation completed successfully'));
    } catch (e, st) {
      updateState({'error': e.toString(), 'stackTrace': st.toString()});
      rethrow;
    }

    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
    await saveState();
  }

  Future<void> _validateChecksum(
      String filePath, String expectedChecksum) async {
    final fileContent =
        await FileUtils.readFile(filePath, fileSystem: fileSystem);
    final computedChecksum = sha256.convert(fileContent.codeUnits).toString();

    emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Computed checksum: $computedChecksum'));
    updateState({'actualChecksum': computedChecksum});

    if (computedChecksum != expectedChecksum) {
      throw ChecksumValidationException(
          filePath, expectedChecksum, computedChecksum);
    }

    logger.info('Checksum validation passed for $filePath');
  }

  Future<void> _validateFormat(String filePath, String format) async {
    emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Format validation started'));
    final fileContent =
        await FileUtils.readFile(filePath, fileSystem: fileSystem);

    try {
      switch (format.toLowerCase()) {
        case 'json':
          json.decode(fileContent);
          break;
        case 'yaml':
          if (fileContent.trim().isEmpty) {
            throw FormatException('Empty YAML file');
          }
          break;
        default:
          throw UnsupportedError('Unsupported format: $format');
      }
      updateState({'formatValidated': true});
      logger.info('Format validation passed for $filePath');
    } catch (e) {
      throw FormatValidationException(filePath, format, e);
    }
  }

  @override
  Future<void> rollback() async {
    // Validation is read-only, just track the rollback attempt
    updateState({'rollbackAttempted': true});

    for (var module in childModules) {
      await module.rollback();
    }

    await saveState();
  }
}