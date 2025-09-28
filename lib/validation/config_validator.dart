import 'dart:convert';

import 'package:configr/exceptions.dart';

/// Validation rule types
enum ValidationRuleType {
  required,
  type,
  range,
  pattern,
  custom,
  enumValue,
  array,
  object,
  length,
  format,
}

/// Validation rule definition
class ValidationRule {
  final ValidationRuleType type;
  final dynamic value;
  final String? message;
  final Map<String, dynamic>? options;

  const ValidationRule({
    required this.type,
    this.value,
    this.message,
    this.options,
  });

  factory ValidationRule.fromMap(Map<String, dynamic> map) {
    return ValidationRule(
      type: ValidationRuleType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ValidationRuleType.custom,
      ),
      value: map['value'],
      message: map['message'] as String?,
      options: map['options'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'value': value,
      'message': message,
      'options': options,
    };
  }
}

/// Validation result
class ValidationResult {
  final bool isValid;
  final List<ValidationError> errors;
  final List<ValidationWarning> warnings;

  const ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  /// Check if validation passed
  bool get hasErrors => errors.isNotEmpty;

  /// Check if there are warnings
  bool get hasWarnings => warnings.isNotEmpty;

  /// Get all issues (errors and warnings)
  List<ValidationIssue> get allIssues => [...errors, ...warnings];

  Map<String, dynamic> toMap() {
    return {
      'isValid': isValid,
      'errors': errors.map((e) => e.toMap()).toList(),
      'warnings': warnings.map((w) => w.toMap()).toList(),
    };
  }
}

/// Base validation issue
abstract class ValidationIssue {
  final String path;
  final String message;
  final String? code;
  final Map<String, dynamic>? details;

  const ValidationIssue({
    required this.path,
    required this.message,
    this.code,
    this.details,
  });

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'message': message,
      'code': code,
      'details': details,
    };
  }
}

/// Validation error
class ValidationError extends ValidationIssue {
  const ValidationError({
    required super.path,
    required super.message,
    super.code,
    super.details,
  });
}

/// Validation warning
class ValidationWarning extends ValidationIssue {
  const ValidationWarning({
    required super.path,
    required super.message,
    super.code,
    super.details,
  });
}

/// Configuration schema definition
class ConfigSchema {
  final String name;
  final String version;
  final Map<String, ValidationRule> properties;
  final List<ValidationRule> globalRules;
  final Map<String, dynamic>? metadata;

  const ConfigSchema({
    required this.name,
    required this.version,
    this.properties = const {},
    this.globalRules = const [],
    this.metadata,
  });

  factory ConfigSchema.fromMap(Map<String, dynamic> map) {
    final properties = <String, ValidationRule>{};
    if (map['properties'] != null) {
      for (final entry in (map['properties'] as Map<String, dynamic>).entries) {
        properties[entry.key] = ValidationRule.fromMap(entry.value as Map<String, dynamic>);
      }
    }

    final globalRules = <ValidationRule>[];
    if (map['globalRules'] != null) {
      for (final rule in (map['globalRules'] as List<dynamic>)) {
        globalRules.add(ValidationRule.fromMap(rule as Map<String, dynamic>));
      }
    }

    return ConfigSchema(
      name: map['name'] as String,
      version: map['version'] as String,
      properties: properties,
      globalRules: globalRules,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'version': version,
      'properties': properties.map((k, v) => MapEntry(k, v.toMap())),
      'globalRules': globalRules.map((r) => r.toMap()).toList(),
      'metadata': metadata,
    };
  }
}

/// Configuration validator
class ConfigValidator {
  static final ConfigValidator _instance = ConfigValidator._internal();

  factory ConfigValidator() => _instance;

  ConfigValidator._internal();

  final Map<String, ConfigSchema> _schemas = {};
  final Map<String, ValidationRule Function(dynamic)> _customValidators = {};

  /// Register a configuration schema
  void registerSchema(ConfigSchema schema) {
    _schemas[schema.name] = schema;
  }

  /// Unregister a configuration schema
  void unregisterSchema(String name) {
    _schemas.remove(name);
  }

  /// Get a registered schema
  ConfigSchema? getSchema(String name) {
    return _schemas[name];
  }

  /// Register a custom validator
  void registerCustomValidator(String name, ValidationRule Function(dynamic) validator) {
    _customValidators[name] = validator;
  }

  /// Validate configuration against a schema
  ValidationResult validate(String schemaName, Map<String, dynamic> config) {
    final schema = _schemas[schemaName];
    if (schema == null) {
      throw ValidationFailedException(
        'Schema not found: $schemaName',
        moduleId: 'ConfigValidator',
        correlationId: null,
      );
    }

    final errors = <ValidationError>[];
    final warnings = <ValidationWarning>[];

    // Validate properties
    for (final entry in schema.properties.entries) {
      final path = entry.key;
      final rule = entry.value;
      final value = config[path];

      final result = _validateValue(path, value, rule);
      errors.addAll(result.errors);
      warnings.addAll(result.warnings);
    }

    // Validate global rules
    for (final rule in schema.globalRules) {
      final result = _validateGlobalRule(config, rule);
      errors.addAll(result.errors);
      warnings.addAll(result.warnings);
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Validate a value against a rule
  ValidationResult _validateValue(String path, dynamic value, ValidationRule rule) {
    final errors = <ValidationError>[];
    final warnings = <ValidationWarning>[];

    switch (rule.type) {
      case ValidationRuleType.required:
        if (value == null) {
          errors.add(ValidationError(
            path: path,
            message: rule.message ?? 'Field is required',
            code: 'REQUIRED',
          ));
        }
        break;

      case ValidationRuleType.type:
        if (value != null && !_isType(value, rule.value as String)) {
          errors.add(ValidationError(
            path: path,
            message: rule.message ?? 'Invalid type. Expected: ${rule.value}',
            code: 'INVALID_TYPE',
          ));
        }
        break;

      case ValidationRuleType.range:
        if (value != null && value is num) {
          final range = rule.value as Map<String, dynamic>;
          final min = range['min'] as num?;
          final max = range['max'] as num?;
          
          if (min != null && value < min) {
            errors.add(ValidationError(
              path: path,
              message: rule.message ?? 'Value must be >= $min',
              code: 'RANGE_MIN',
            ));
          }
          
          if (max != null && value > max) {
            errors.add(ValidationError(
              path: path,
              message: rule.message ?? 'Value must be <= $max',
              code: 'RANGE_MAX',
            ));
          }
        }
        break;

      case ValidationRuleType.pattern:
        if (value != null && value is String) {
          final pattern = rule.value as String;
          final regex = RegExp(pattern);
          if (!regex.hasMatch(value)) {
            errors.add(ValidationError(
              path: path,
              message: rule.message ?? 'Value does not match pattern: $pattern',
              code: 'PATTERN_MISMATCH',
            ));
          }
        }
        break;

      case ValidationRuleType.enumValue:
        if (value != null) {
          final allowedValues = rule.value as List<dynamic>;
          if (!allowedValues.contains(value)) {
            errors.add(ValidationError(
              path: path,
              message: rule.message ?? 'Value must be one of: ${allowedValues.join(', ')}',
              code: 'INVALID_ENUM',
            ));
          }
        }
        break;

      case ValidationRuleType.array:
        if (value != null && value is! List) {
          errors.add(ValidationError(
            path: path,
            message: rule.message ?? 'Value must be an array',
            code: 'INVALID_ARRAY',
          ));
        } else if (value is List) {
          final arrayRule = rule.options?['itemRule'] as ValidationRule?;
          if (arrayRule != null) {
            for (int i = 0; i < value.length; i++) {
              final itemResult = _validateValue('$path[$i]', value[i], arrayRule);
              errors.addAll(itemResult.errors);
              warnings.addAll(itemResult.warnings);
            }
          }
        }
        break;

      case ValidationRuleType.object:
        if (value != null && value is! Map) {
          errors.add(ValidationError(
            path: path,
            message: rule.message ?? 'Value must be an object',
            code: 'INVALID_OBJECT',
          ));
        }
        break;

      case ValidationRuleType.length:
        if (value != null) {
          final lengthRule = rule.value as Map<String, dynamic>;
          final minLength = lengthRule['min'] as int?;
          final maxLength = lengthRule['max'] as int?;
          
          int? actualLength;
          if (value is String) {
            actualLength = value.length;
          } else if (value is List) {
            actualLength = value.length;
          } else if (value is Map) {
            actualLength = value.length;
          }
          
          if (actualLength != null) {
            if (minLength != null && actualLength < minLength) {
              errors.add(ValidationError(
                path: path,
                message: rule.message ?? 'Length must be >= $minLength',
                code: 'LENGTH_MIN',
              ));
            }
            
            if (maxLength != null && actualLength > maxLength) {
              errors.add(ValidationError(
                path: path,
                message: rule.message ?? 'Length must be <= $maxLength',
                code: 'LENGTH_MAX',
              ));
            }
          }
        }
        break;

      case ValidationRuleType.format:
        if (value != null && value is String) {
          final format = rule.value as String;
          if (!_isValidFormat(value, format)) {
            errors.add(ValidationError(
              path: path,
              message: rule.message ?? 'Invalid format: $format',
              code: 'INVALID_FORMAT',
            ));
          }
        }
        break;

      case ValidationRuleType.custom:
        final validatorName = rule.value as String;
        final validator = _customValidators[validatorName];
        if (validator != null) {
          try {
            final customRule = validator(value);
            final result = _validateValue(path, value, customRule);
            errors.addAll(result.errors);
            warnings.addAll(result.warnings);
          } catch (e) {
            errors.add(ValidationError(
              path: path,
              message: 'Custom validation failed: ${e.toString()}',
              code: 'CUSTOM_VALIDATION_ERROR',
            ));
          }
        }
        break;
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Validate global rule
  ValidationResult _validateGlobalRule(Map<String, dynamic> config, ValidationRule rule) {
    final errors = <ValidationError>[];
    final warnings = <ValidationWarning>[];

    // Global rules are applied to the entire configuration
    // This is a simplified implementation
    if (rule.type == ValidationRuleType.custom) {
      final validatorName = rule.value as String;
      final validator = _customValidators[validatorName];
      if (validator != null) {
        try {
          final customRule = validator(config);
          final result = _validateValue('', config, customRule);
          errors.addAll(result.errors);
          warnings.addAll(result.warnings);
        } catch (e) {
          errors.add(ValidationError(
            path: '',
            message: 'Global validation failed: ${e.toString()}',
            code: 'GLOBAL_VALIDATION_ERROR',
          ));
        }
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Check if value is of specified type
  bool _isType(dynamic value, String type) {
    switch (type.toLowerCase()) {
      case 'string':
        return value is String;
      case 'number':
        return value is num;
      case 'integer':
        return value is int;
      case 'boolean':
        return value is bool;
      case 'array':
        return value is List;
      case 'object':
        return value is Map;
      case 'null':
        return value == null;
      default:
        return false;
    }
  }

  /// Check if value matches format
  bool _isValidFormat(String value, String format) {
    switch (format.toLowerCase()) {
      case 'email':
        return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value);
      case 'url':
        return RegExp(r'^https?://').hasMatch(value);
      case 'uuid':
        return RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false).hasMatch(value);
      case 'date':
        try {
          DateTime.parse(value);
          return true;
        } catch (e) {
          return false;
        }
      case 'json':
        try {
          jsonDecode(value);
          return true;
        } catch (e) {
          return false;
        }
      default:
        return true; // Unknown format, assume valid
    }
  }

  /// Get all registered schemas
  Map<String, ConfigSchema> get schemas => Map.unmodifiable(_schemas);

  /// Clear all schemas and validators
  void clear() {
    _schemas.clear();
    _customValidators.clear();
  }
}
