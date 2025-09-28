import 'package:configr/exceptions.dart';

/// Aggregates multiple errors and provides graceful degradation
class ErrorAggregator {
  final List<ModuleException> _errors = [];
  final List<ModuleException> _warnings = [];
  final String? _operationName;
  final String? _moduleId;
  final String? _correlationId;

  ErrorAggregator({
    String? operationName,
    String? moduleId,
    String? correlationId,
  }) : _operationName = operationName,
       _moduleId = moduleId,
       _correlationId = correlationId;

  /// Add an error to the aggregator
  void addError(ModuleException error) {
    _errors.add(error);
  }

  /// Add a warning to the aggregator
  void addWarning(ModuleException warning) {
    _warnings.add(warning);
  }

  /// Add multiple errors at once
  void addErrors(List<ModuleException> errors) {
    _errors.addAll(errors);
  }

  /// Add multiple warnings at once
  void addWarnings(List<ModuleException> warnings) {
    _warnings.addAll(warnings);
  }

  /// Check if there are any errors
  bool get hasErrors => _errors.isNotEmpty;

  /// Check if there are any warnings
  bool get hasWarnings => _warnings.isNotEmpty;

  /// Check if there are any issues (errors or warnings)
  bool get hasIssues => hasErrors || hasWarnings;

  /// Get all errors
  List<ModuleException> get errors => List.unmodifiable(_errors);

  /// Get all warnings
  List<ModuleException> get warnings => List.unmodifiable(_warnings);

  /// Get all issues (errors and warnings)
  List<ModuleException> get allIssues => [..._errors, ..._warnings];

  /// Get errors by severity
  List<ModuleException> getErrorsBySeverity(ErrorSeverity severity) {
    return _errors.where((e) => e.severity == severity).toList();
  }

  /// Get errors by category
  List<ModuleException> getErrorsByCategory(ErrorCategory category) {
    return _errors.where((e) => e.category == category).toList();
  }

  /// Get critical errors
  List<ModuleException> get criticalErrors => 
      getErrorsBySeverity(ErrorSeverity.critical);

  /// Get high severity errors
  List<ModuleException> get highSeverityErrors => 
      getErrorsBySeverity(ErrorSeverity.high);

  /// Check if there are critical errors
  bool get hasCriticalErrors => criticalErrors.isNotEmpty;

  /// Check if there are high severity errors
  bool get hasHighSeverityErrors => highSeverityErrors.isNotEmpty;

  /// Get a summary of all issues
  ErrorSummary getSummary() {
    return ErrorSummary(
      totalErrors: _errors.length,
      totalWarnings: _warnings.length,
      criticalErrors: criticalErrors.length,
      highSeverityErrors: highSeverityErrors.length,
      errorsByCategory: _getErrorsByCategory(),
      errorsBySeverity: _getErrorsBySeverity(),
      operationName: _operationName,
      moduleId: _moduleId,
      correlationId: _correlationId,
    );
  }

  /// Throw a ConfigurationFailedException if there are critical errors
  void throwIfCritical() {
    if (hasCriticalErrors) {
      throw ConfigurationFailedException(
        criticalErrors,
        moduleId: _moduleId,
        correlationId: _correlationId,
      );
    }
  }

  /// Throw a ConfigurationFailedException if there are any errors
  void throwIfAnyErrors() {
    if (hasErrors) {
      throw ConfigurationFailedException(
        _errors,
        moduleId: _moduleId,
        correlationId: _correlationId,
      );
    }
  }

  /// Get errors grouped by category
  Map<ErrorCategory, List<ModuleException>> _getErrorsByCategory() {
    final Map<ErrorCategory, List<ModuleException>> grouped = {};
    
    for (final error in _errors) {
      grouped.putIfAbsent(error.category, () => []).add(error);
    }
    
    return grouped;
  }

  /// Get errors grouped by severity
  Map<ErrorSeverity, List<ModuleException>> _getErrorsBySeverity() {
    final Map<ErrorSeverity, List<ModuleException>> grouped = {};
    
    for (final error in _errors) {
      grouped.putIfAbsent(error.severity, () => []).add(error);
    }
    
    return grouped;
  }

  /// Clear all errors and warnings
  void clear() {
    _errors.clear();
    _warnings.clear();
  }

  /// Create a new aggregator for a sub-operation
  ErrorAggregator createSubAggregator(String operationName) {
    return ErrorAggregator(
      operationName: operationName,
      moduleId: _moduleId,
      correlationId: _correlationId,
    );
  }

  /// Merge another aggregator's issues into this one
  void merge(ErrorAggregator other) {
    _errors.addAll(other._errors);
    _warnings.addAll(other._warnings);
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    
    if (_operationName != null) {
      buffer.writeln('ErrorAggregator for operation: $_operationName');
    }
    
    if (hasErrors) {
      buffer.writeln('Errors (${_errors.length}):');
      for (final error in _errors) {
        buffer.writeln('  - ${error.errorCode}: ${error.message}');
      }
    }
    
    if (hasWarnings) {
      buffer.writeln('Warnings (${_warnings.length}):');
      for (final warning in _warnings) {
        buffer.writeln('  - ${warning.errorCode}: ${warning.message}');
      }
    }
    
    return buffer.toString();
  }
}

/// Summary of errors and warnings
class ErrorSummary {
  final int totalErrors;
  final int totalWarnings;
  final int criticalErrors;
  final int highSeverityErrors;
  final Map<ErrorCategory, List<ModuleException>> errorsByCategory;
  final Map<ErrorSeverity, List<ModuleException>> errorsBySeverity;
  final String? operationName;
  final String? moduleId;
  final String? correlationId;

  const ErrorSummary({
    required this.totalErrors,
    required this.totalWarnings,
    required this.criticalErrors,
    required this.highSeverityErrors,
    required this.errorsByCategory,
    required this.errorsBySeverity,
    this.operationName,
    this.moduleId,
    this.correlationId,
  });

  /// Check if the operation was successful (no errors)
  bool get isSuccessful => totalErrors == 0;

  /// Check if the operation had critical issues
  bool get hasCriticalIssues => criticalErrors > 0;

  /// Check if the operation had high severity issues
  bool get hasHighSeverityIssues => highSeverityErrors > 0;

  /// Get the overall severity of the operation
  ErrorSeverity get overallSeverity {
    if (criticalErrors > 0) return ErrorSeverity.critical;
    if (highSeverityErrors > 0) return ErrorSeverity.high;
    if (totalErrors > 0) return ErrorSeverity.medium;
    if (totalWarnings > 0) return ErrorSeverity.low;
    return ErrorSeverity.low;
  }

  /// Get a human-readable summary
  String get summary {
    final buffer = StringBuffer();
    
    if (isSuccessful) {
      buffer.write('Operation completed successfully');
      if (totalWarnings > 0) {
        buffer.write(' with $totalWarnings warning(s)');
      }
    } else {
      buffer.write('Operation failed with $totalErrors error(s)');
      if (totalWarnings > 0) {
        buffer.write(' and $totalWarnings warning(s)');
      }
    }
    
    return buffer.toString();
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    
    buffer.writeln('ErrorSummary:');
    buffer.writeln('  Total Errors: $totalErrors');
    buffer.writeln('  Total Warnings: $totalWarnings');
    buffer.writeln('  Critical Errors: $criticalErrors');
    buffer.writeln('  High Severity Errors: $highSeverityErrors');
    buffer.writeln('  Overall Severity: ${overallSeverity.name}');
    
    if (errorsByCategory.isNotEmpty) {
      buffer.writeln('  Errors by Category:');
      for (final entry in errorsByCategory.entries) {
        buffer.writeln('    ${entry.key.name}: ${entry.value.length}');
      }
    }
    
    return buffer.toString();
  }
}
