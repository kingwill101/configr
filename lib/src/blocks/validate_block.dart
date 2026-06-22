import 'dart:convert';

import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/file_utils.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:i3config/i3config_v2.dart' as i3;
import 'package:yaml/yaml.dart' show loadYaml;

/// Block handler for the `validate` config action.
///
/// Performs read-only validation of a file: checksum, format, schema, and
/// custom rules. Rollback is a no-op since validation doesn't modify state.
///
/// ```i3
/// validate {
///   source = "/path/to/file"
///   checksum = "abc123..."
///   format = "json"           # json | yaml | yml
///   schema = "/path/to/schema"
///   strict_mode = true
/// }
/// ```
class ValidateBlock extends ActionBlock {
  @override
  String get blockType => 'validate';

  String? checksum;
  String? format;
  String? schema;
  bool strictMode = false;
  List<String> customRules = [];
  List<String> requiredFields = [];

  // Execution state
  String? actualChecksum;
  bool sourceExists = false;

  ValidateBlock({super.fileSystem, super.eventBus});

  @override
  Map<String, String> get additionalProperties => {
    if (checksum != null) 'checksum': checksum!,
    if (format != null) 'format': format!,
    if (schema != null) 'schema': schema!,
    if (customRules.isNotEmpty) 'custom_rules': customRules.join(', '),
    if (requiredFields.isNotEmpty) 'required_fields': requiredFields.join(', '),
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (strictMode) 'strict_mode': strictMode,
  };

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);

    checksum = context.getVariable('checksum') as String?;
    format = context.getVariable('format') as String?;
    schema = context.getVariable('schema') as String?;
    strictMode = switch (context.getVariable('strict_mode')) {
      true || 'true' => true,
      _ => false,
    };
    final rules = context.getVariable('custom_rules');
    if (rules is String) {
      customRules = rules.split(',').map((s) => s.trim()).toList();
    } else if (rules is List) {
      customRules = rules.cast<String>();
    }

    final fields = context.getVariable('required_fields');
    if (fields is String) {
      requiredFields = fields.split(',').map((s) => s.trim()).toList();
    } else if (fields is List) {
      requiredFields = fields.cast<String>();
    }
  }

  @override
  Future<void> execute() async {
    emitEvent(
      StartedEvent(moduleId: id, message: 'Starting validation of $source'),
    );

    final sourcePath = source;
    sourceExists = await FileUtils.fileExists(
      sourcePath,
      fileSystem: fileSystem,
    );
    if (!sourceExists) {
      throw SourceNotFoundException(sourcePath);
    }

    try {
      if (checksum != null) {
        emitEvent(
          StatusUpdateEvent(
            moduleId: id,
            level: StatusEvent.info,
            message: 'Validating checksum',
          ),
        );
        await _validateChecksum(sourcePath, checksum!);
      }

      if (format != null) {
        emitEvent(
          StatusUpdateEvent(
            moduleId: id,
            level: StatusEvent.info,
            message: 'Validating format: $format',
          ),
        );
        await _validateFormat(sourcePath, format!);
      }

      if (schema != null) {
        emitEvent(
          StatusUpdateEvent(
            moduleId: id,
            level: StatusEvent.info,
            message: 'Validating against schema',
          ),
        );
        await _validateSchema(sourcePath, schema!);
      }

      if (customRules.isNotEmpty) {
        emitEvent(
          StatusUpdateEvent(
            moduleId: id,
            level: StatusEvent.info,
            message: 'Validating custom rules',
          ),
        );
        await _validateCustomRules(sourcePath, customRules);
      }

      if (requiredFields.isNotEmpty) {
        emitEvent(
          StatusUpdateEvent(
            moduleId: id,
            level: StatusEvent.info,
            message: 'Validating required fields',
          ),
        );
        await _validateRequiredFields(sourcePath, requiredFields);
      }

      emitEvent(
        CompletedEvent(
          moduleId: id,
          message: 'Validation completed successfully',
        ),
      );
    } catch (e, st) {
      emitEvent(FailedEvent(moduleId: id, message: 'Validation failed: $e'));
      throw ActionFailedException(
        'Validation failed for $sourcePath',
        moduleId: id,
        cause: e,
        stackTrace: st,
      );
    }

    status = 'completed';
  }

  @override
  Future<void> rollback() async {
    // Validation is read-only — nothing to undo.
  }

  Future<void> _validateChecksum(
    String filePath,
    String expectedChecksum,
  ) async {
    final content = await FileUtils.readFile(filePath, fileSystem: fileSystem);
    final computed = sha256.convert(utf8.encode(content)).toString();
    actualChecksum = computed;

    emitEvent(
      StatusUpdateEvent(
        moduleId: id,
        level: StatusEvent.info,
        message: 'Computed checksum: $computed',
      ),
    );

    if (computed != expectedChecksum) {
      throw ChecksumValidationException(filePath, expectedChecksum, computed);
    }
    logger.info('Checksum validation passed for $filePath');
  }

  Future<void> _validateFormat(String filePath, String fmt) async {
    final content = await FileUtils.readFile(filePath, fileSystem: fileSystem);

    try {
      switch (fmt.toLowerCase()) {
        case 'json':
          json.decode(content);
        case 'yaml':
        case 'yml':
          if (content.trim().isEmpty) throw FormatException('Empty YAML file');
          loadYaml(content);
        default:
          throw UnsupportedError('Unsupported format: $fmt');
      }
      logger.info('Format validation passed for $filePath');
    } catch (e) {
      throw FormatValidationException(filePath, fmt, moduleId: id, cause: e);
    }
  }

  Future<void> _validateSchema(String filePath, String schemaPath) async {
    final fileContent = await FileUtils.readFile(
      filePath,
      fileSystem: fileSystem,
    );
    final schemaContent = await FileUtils.readFile(
      schemaPath,
      fileSystem: fileSystem,
    );

    try {
      // Determine format from file extension or explicit format
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
            throw UnsupportedError(
              'Schema validation not supported for format: $format',
            );
        }
      } else {
        try {
          fileData = json.decode(fileContent);
          schemaData = json.decode(schemaContent);
        } catch (_) {
          throw FormatException(
            'Unable to auto-detect format for schema validation',
          );
        }
      }

      if (fileData is Map<String, dynamic>) {
        _validateJsonAgainstSchema(
          fileData,
          schemaData as Map<String, dynamic>,
        );
      } else if (fileData is Map) {
        final castData = fileData.cast<String, dynamic>();
        _validateJsonAgainstSchema(
          castData,
          (schemaData as Map).cast<String, dynamic>(),
        );
      }

      logger.info('Schema validation passed for $filePath');
    } catch (e) {
      throw FormatValidationException(
        filePath,
        'schema',
        moduleId: id,
        cause: e,
      );
    }
  }

  void _validateYamlAgainstSchema(dynamic yamlData, dynamic schemaData) {
    if (schemaData is Map) {
      final schemaKeys = schemaData.keys.cast<String>().toSet();
      if (yamlData is Map) {
        final yamlKeys = yamlData.keys.cast<String>().toSet();
        for (final key in schemaKeys) {
          if (!yamlKeys.contains(key)) {
            throw FormatException('Required key "$key" not found in YAML file');
          }
        }
        if (strictMode) {
          for (final key in yamlKeys) {
            if (!schemaKeys.contains(key)) {
              throw FormatException(
                'Unknown key "$key" found in YAML file (strict mode)',
              );
            }
          }
        }
      } else {
        throw FormatException(
          'YAML file must be an object for schema validation',
        );
      }
    }
  }

  void _validateJsonAgainstSchema(
    Map<String, dynamic> fileData,
    dynamic schemaData,
  ) {
    if (schemaData is Map<String, dynamic>) {
      final requiredKeys = <String>[];
      final optionalKeys = <String>[];
      for (final entry in schemaData.entries) {
        if (entry.value is Map && entry.value['required'] == true) {
          requiredKeys.add(entry.key);
        } else {
          optionalKeys.add(entry.key);
        }
      }
      final fileKeys = fileData.keys.toSet();
      for (final key in requiredKeys) {
        if (!fileKeys.contains(key)) {
          throw FormatException('Required key "$key" not found');
        }
      }
      if (strictMode) {
        final allowed = {...requiredKeys, ...optionalKeys};
        for (final key in fileKeys) {
          if (!allowed.contains(key)) {
            throw FormatException('Unknown key "$key" found (strict mode)');
          }
        }
      }
    }
  }

  Future<void> _validateCustomRules(String filePath, List<String> rules) async {
    final content = await FileUtils.readFile(filePath, fileSystem: fileSystem);
    for (final rule in rules) {
      await _applyCustomRule(filePath, content, rule);
    }
    logger.info('Custom rules validation passed for $filePath');
  }

  Future<void> _validateRequiredFields(
    String filePath,
    List<String> fields,
  ) async {
    final content = await FileUtils.readFile(filePath, fileSystem: fileSystem);

    // Determine data type from format or content
    dynamic data;
    if (format != null) {
      switch (format!.toLowerCase()) {
        case 'json':
          data = json.decode(content);
        case 'yaml':
        case 'yml':
          data = loadYaml(content);
        default:
          // For other formats, check raw text
          data = null;
      }
    } else {
      try {
        data = json.decode(content);
      } catch (_) {
        data = null;
      }
    }

    if (data is Map) {
      final keys = data.keys.cast<String>().toSet();
      for (final field in fields) {
        if (!keys.contains(field)) {
          throw FormatException(
            'Required field "$field" not found in $filePath',
          );
        }
      }
      logger.info('Required fields validation passed for $filePath');
    } else {
      logger.warning(
        'Cannot validate required fields — $filePath is not a structured data file',
      );
    }
  }

  Future<void> _applyCustomRule(
    String filePath,
    String content,
    String rule,
  ) async {
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
      case 'regex':
        final regex = RegExp(value);
        if (condition == 'must' && !regex.hasMatch(content)) {
          throw FormatException('Content must match regex: $value');
        } else if (condition == 'mustnot' && regex.hasMatch(content)) {
          throw FormatException('Content must not match regex: $value');
        }
      case 'length':
        final length = int.tryParse(value);
        if (length != null) {
          if (condition == 'min' && content.length < length) {
            throw FormatException('Content length must be at least $length');
          } else if (condition == 'max' && content.length > length) {
            throw FormatException('Content length must be at most $length');
          } else if (condition == 'exact' && content.length != length) {
            throw FormatException('Content length must be exactly $length');
          }
        }
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
      default:
        throw FormatException('Unknown custom rule type: $ruleType');
    }
  }
}
