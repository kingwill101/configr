import 'dart:convert';
import 'package:configr/events/module_events.dart';
import 'package:configr/exceptions.dart';
import 'package:crypto/crypto.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/file_utils.dart';
import 'package:configr/utils/logging.dart';
import 'package:configr/utils/event_bus.dart';
import 'package:yaml/yaml.dart';

class FileValidateModule extends ResourceModule {
  // State getters
  String? get checksum => state['checksum'] as String?;
  String? get format => state['format'] as String?;
  String? get actualChecksum => state['actualChecksum'] as String?;
  bool get sourceExists => state['sourceExists'] as bool? ?? false;
  String? get schema => state['schema'] as String?;
  List<String> get customRules => (state['customRules'] as List<dynamic>?)?.cast<String>() ?? [];
  bool get strictMode => state['strictMode'] as bool? ?? false;
  Map<String, dynamic> get validationResults => state['validationResults'] as Map<String, dynamic>? ?? {};

  FileValidateModule(super.file, super.action,
      {super.allowedActions = const ['validate'], super.fileSystem}) {
    updateState({
      'checksum': action.properties['checksum'],
      'format': action.properties['format'],
      'schema': action.properties['schema'],
      'customRules': action.properties['customRules'] ?? [],
      'strictMode': action.properties['strictMode'] ?? false,
      'actualChecksum': null,
      'sourceExists': false,
      'validationResults': {}
    });
  }

  @override
  Future<void> execute() async {
    emitEvent(StartedEvent(moduleId: action.id, message: 'Starting file validation'));
    // Use file_path property if specified, otherwise use source
    final sourcePath = action.properties['file_path'] as String? ?? source;
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
      final validationResults = <String, dynamic>{};
      
      if (checksum != null) {
        emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Validating checksum'));
        emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Expected checksum: $checksum'));
        await _validateChecksum(sourcePath, checksum!);
        validationResults['checksum'] = 'passed';
      }

      if (format != null) {
        emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Validating format: $format'));
        await _validateFormat(sourcePath, format!);
        validationResults['format'] = 'passed';
      }

      if (schema != null) {
        emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Validating against schema'));
        await _validateSchema(sourcePath, schema!);
        validationResults['schema'] = 'passed';
      }

      if (customRules.isNotEmpty) {
        emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Validating custom rules'));
        await _validateCustomRules(sourcePath, customRules);
        validationResults['customRules'] = 'passed';
      }

      updateState({
        'validationCompleted': true,
        'validationResults': validationResults
      });
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
        case 'yml':
          if (fileContent.trim().isEmpty) {
            throw FormatException('Empty YAML file');
          }
          // Use proper YAML parsing
          loadYaml(fileContent);
          break;
        default:
          throw UnsupportedError('Unsupported format: $format');
      }
      updateState({'formatValidated': true});
      logger.info('Format validation passed for $filePath');
    } catch (e) {
      throw FormatValidationException(filePath, format, moduleId: action.id, cause: e);
    }
  }



  Future<void> _validateSchema(String filePath, String schemaPath) async {
    emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Schema validation started'));
    final fileContent = await FileUtils.readFile(filePath, fileSystem: fileSystem);
    final schemaContent = await FileUtils.readFile(schemaPath, fileSystem: fileSystem);
    
    try {
      // Parse the file content based on format
      dynamic fileData;
      dynamic schemaData;
      
      if (format != null) {
        switch (format!.toLowerCase()) {
          case 'json':
            fileData = json.decode(fileContent);
            schemaData = json.decode(schemaContent);
            break;
          case 'yaml':
          case 'yml':
            fileData = loadYaml(fileContent);
            schemaData = loadYaml(schemaContent);
            _validateYamlAgainstSchema(fileData, schemaData);
            return;
          default:
            throw UnsupportedError('Schema validation not supported for format: $format');
        }
      } else {
        // Try to auto-detect format
        try {
          fileData = json.decode(fileContent);
          schemaData = json.decode(schemaContent);
        } catch (e) {
          throw FormatException('Unable to auto-detect format for schema validation');
        }
      }
      
      // Basic schema validation for JSON
      if (format == 'json' || fileData is Map) {
        _validateJsonAgainstSchema(fileData, schemaData);
      }
      
      updateState({'schemaValidated': true});
      logger.info('Schema validation passed for $filePath');
    } catch (e) {
      throw FormatValidationException(filePath, 'schema', moduleId: action.id, cause: e);
    }
  }

  void _validateYamlAgainstSchema(dynamic yamlData, dynamic schemaData) {
    // YAML schema validation using parsed data
    if (schemaData is Map) {
      final schemaKeys = schemaData.keys.cast<String>().toSet();
      
      if (yamlData is Map) {
        final yamlKeys = yamlData.keys.cast<String>().toSet();
        
        // Check if all required keys are present
        for (final key in schemaKeys) {
          if (!yamlKeys.contains(key)) {
            throw FormatException('Required key "$key" not found in YAML file');
          }
        }
        
        // Check for unknown keys in strict mode
        if (strictMode) {
          for (final key in yamlKeys) {
            if (!schemaKeys.contains(key)) {
              throw FormatException('Unknown key "$key" found in YAML file (strict mode enabled)');
            }
          }
        }
      } else {
        throw FormatException('YAML file must be an object for schema validation');
      }
    }
  }


  void _validateJsonAgainstSchema(dynamic fileData, dynamic schemaData) {
    if (schemaData is Map<String, dynamic>) {
      final requiredKeys = <String>[];
      final optionalKeys = <String>[];
      
      // Extract required and optional keys from schema
      for (final entry in schemaData.entries) {
        if (entry.value is Map && entry.value['required'] == true) {
          requiredKeys.add(entry.key);
        } else {
          optionalKeys.add(entry.key);
        }
      }
      
      if (fileData is Map<String, dynamic>) {
        final fileKeys = fileData.keys.toSet();
        
        // Check required keys
        for (final key in requiredKeys) {
          if (!fileKeys.contains(key)) {
            throw FormatException('Required key "$key" not found in JSON file');
          }
        }
        
        // Check for unknown keys in strict mode
        if (strictMode) {
          final allowedKeys = {...requiredKeys, ...optionalKeys};
          for (final key in fileKeys) {
            if (!allowedKeys.contains(key)) {
              throw FormatException('Unknown key "$key" found in JSON file (strict mode enabled)');
            }
          }
        }
      } else {
        throw FormatException('JSON file must be an object for schema validation');
      }
    }
  }

  Future<void> _validateCustomRules(String filePath, List<String> rules) async {
    emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Custom rules validation started'));
    final fileContent = await FileUtils.readFile(filePath, fileSystem: fileSystem);
    
    try {
      for (final rule in rules) {
        await _applyCustomRule(filePath, fileContent, rule);
      }
      
      updateState({'customRulesValidated': true});
      logger.info('Custom rules validation passed for $filePath');
    } catch (e) {
      throw FormatValidationException(filePath, 'custom rules', moduleId: action.id, cause: e);
    }
  }

  Future<void> _applyCustomRule(String filePath, String content, String rule) async {
    // Parse custom rule format: "type:condition:value"
    final parts = rule.split(':');
    if (parts.length < 2) {
      throw FormatException('Invalid custom rule format: $rule');
    }
    
    final ruleType = parts[0].toLowerCase();
    final condition = parts[1].toLowerCase();
    final value = parts.length > 2 ? parts[2] : '';
    
    switch (ruleType) {
      case 'contains':
        if (condition == 'must' && !content.contains(value)) {
          throw FormatException('Content must contain "$value"');
        } else if (condition == 'mustnot' && content.contains(value)) {
          throw FormatException('Content must not contain "$value"');
        }
        break;
      case 'regex':
        final regex = RegExp(value);
        if (condition == 'must' && !regex.hasMatch(content)) {
          throw FormatException('Content must match regex pattern: $value');
        } else if (condition == 'mustnot' && regex.hasMatch(content)) {
          throw FormatException('Content must not match regex pattern: $value');
        }
        break;
      case 'length':
        final length = int.tryParse(value);
        if (length != null) {
          if (condition == 'min' && content.length < length) {
            throw FormatException('Content length must be at least $length characters');
          } else if (condition == 'max' && content.length > length) {
            throw FormatException('Content length must be at most $length characters');
          } else if (condition == 'exact' && content.length != length) {
            throw FormatException('Content length must be exactly $length characters');
          }
        }
        break;
      case 'lines':
        final lineCount = int.tryParse(value);
        if (lineCount != null) {
          final lines = content.split('\n').length;
          if (condition == 'min' && lines < lineCount) {
            throw FormatException('File must have at least $lineCount lines');
          } else if (condition == 'max' && lines > lineCount) {
            throw FormatException('File must have at most $lineCount lines');
          } else if (condition == 'exact' && lines != lineCount) {
            throw FormatException('File must have exactly $lineCount lines');
          }
        }
        break;
      default:
        throw FormatException('Unknown custom rule type: $ruleType');
    }
  }

  @override
  Future<void> rollback() async {
    emitEvent(StartedEvent(moduleId: action.id, message: 'Rolling back validation operation'));
    
    try {
      // Validation is read-only, just track the rollback attempt
      updateState({'rollbackAttempted': true});

      for (var module in childModules) {
        await module.rollback();
      }

      emitEvent(CompletedEvent(moduleId: action.id, message: 'Validation rollback completed'));
      await saveState();
    } catch (e, st) {
      updateState({
        'rollbackError': e.toString(),
        'rollbackStackTrace': st.toString()
      });
      emitEvent(FailedEvent(moduleId: action.id, message: 'Validation rollback failed: ${e.toString()}'));
      rethrow;
    }
  }
}