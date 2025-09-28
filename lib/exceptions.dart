/// Error severity levels for structured error handling
enum ErrorSeverity {
  low,
  medium,
  high,
  critical,
}

/// Error categories for better error classification
enum ErrorCategory {
  validation,
  permission,
  network,
  fileSystem,
  configuration,
  execution,
  security,
  performance,
  unknown,
}

/// Structured error information for enhanced error handling
class ErrorContext {
  final String operation;
  final String? moduleId;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;
  final String? correlationId;

  ErrorContext({
    required this.operation,
    this.moduleId,
    this.metadata,
    DateTime? timestamp,
    this.correlationId,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Enhanced base exception with structured error information
abstract class ModuleException implements Exception {
  final String message;
  final dynamic cause;
  final StackTrace? stackTrace;
  final ErrorSeverity severity;
  final ErrorCategory category;
  final ErrorContext context;
  final String errorCode;
  final bool isRetryable;
  final Duration? retryAfter;

  ModuleException(
    this.message, {
    this.cause,
    this.stackTrace,
    this.severity = ErrorSeverity.medium,
    this.category = ErrorCategory.unknown,
    required this.context,
    this.errorCode = 'UNKNOWN_ERROR',
    this.isRetryable = false,
    this.retryAfter,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('ModuleException: $message');
    buffer.writeln('Error Code: $errorCode');
    buffer.writeln('Severity: ${severity.name}');
    buffer.writeln('Category: ${category.name}');
    buffer.writeln('Operation: ${context.operation}');
    if (context.moduleId != null) {
      buffer.writeln('Module: ${context.moduleId}');
    }
    if (context.correlationId != null) {
      buffer.writeln('Correlation ID: ${context.correlationId}');
    }
    if (isRetryable) {
      buffer.writeln('Retryable: Yes');
      if (retryAfter != null) {
        buffer.writeln('Retry After: ${retryAfter!.inSeconds}s');
      }
    }
    if (cause != null) {
      buffer.writeln('Cause: $cause');
    }
    return buffer.toString();
  }

  /// Convert to structured error data for logging/monitoring
  Map<String, dynamic> toStructuredData() {
    return {
      'errorCode': errorCode,
      'message': message,
      'severity': severity.name,
      'category': category.name,
      'operation': context.operation,
      'moduleId': context.moduleId,
      'correlationId': context.correlationId,
      'timestamp': context.timestamp.toIso8601String(),
      'isRetryable': isRetryable,
      'retryAfter': retryAfter?.inSeconds,
      'metadata': context.metadata,
      'cause': cause?.toString(),
    };
  }
}

class SourceNotFoundException extends ModuleException {
  SourceNotFoundException(
    String path, {
    dynamic cause,
    StackTrace? stackTrace,
    String? moduleId,
    String? correlationId,
  }) : super(
          'Source path not found: $path',
          cause: cause,
          stackTrace: stackTrace,
          severity: ErrorSeverity.high,
          category: ErrorCategory.fileSystem,
          context: ErrorContext(
            operation: 'file_access',
            moduleId: moduleId,
            correlationId: correlationId,
            metadata: {'path': path},
          ),
          errorCode: 'SOURCE_NOT_FOUND',
          isRetryable: false,
        );
}

class DestinationExistsException extends ModuleException {
  DestinationExistsException(
    String path, {
    dynamic cause,
    StackTrace? stackTrace,
    String? moduleId,
    String? correlationId,
  }) : super(
          'Destination already exists: $path',
          cause: cause,
          stackTrace: stackTrace,
          severity: ErrorSeverity.medium,
          category: ErrorCategory.fileSystem,
          context: ErrorContext(
            operation: 'file_creation',
            moduleId: moduleId,
            correlationId: correlationId,
            metadata: {'path': path},
          ),
          errorCode: 'DESTINATION_EXISTS',
          isRetryable: false,
        );
}

class ActionFailedException extends ModuleException {
  ActionFailedException(
    String message, {
    dynamic cause,
    StackTrace? stackTrace,
    String? moduleId,
    String? correlationId,
    ErrorSeverity severity = ErrorSeverity.medium,
    ErrorCategory category = ErrorCategory.execution,
    bool isRetryable = true,
    Duration? retryAfter,
  }) : super(
          message,
          cause: cause,
          stackTrace: stackTrace,
          severity: severity,
          category: category,
          context: ErrorContext(
            operation: 'action_execution',
            moduleId: moduleId,
            correlationId: correlationId,
          ),
          errorCode: 'ACTION_FAILED',
          isRetryable: isRetryable,
          retryAfter: retryAfter,
        );
}

class ValidationFailedException extends ModuleException {
  ValidationFailedException(
    String message, {
    dynamic cause,
    StackTrace? stackTrace,
    String? moduleId,
    String? correlationId,
    Map<String, dynamic>? validationDetails,
  }) : super(
          message,
          cause: cause,
          stackTrace: stackTrace,
          severity: ErrorSeverity.medium,
          category: ErrorCategory.validation,
          context: ErrorContext(
            operation: 'validation',
            moduleId: moduleId,
            correlationId: correlationId,
            metadata: validationDetails,
          ),
          errorCode: 'VALIDATION_FAILED',
          isRetryable: false,
        );
}

class PermissionDeniedException extends ModuleException {
  PermissionDeniedException(
    String path, {
    dynamic cause,
    StackTrace? stackTrace,
    String? moduleId,
    String? correlationId,
  }) : super(
          'Permission denied: $path',
          cause: cause,
          stackTrace: stackTrace,
          severity: ErrorSeverity.high,
          category: ErrorCategory.permission,
          context: ErrorContext(
            operation: 'file_access',
            moduleId: moduleId,
            correlationId: correlationId,
            metadata: {'path': path},
          ),
          errorCode: 'PERMISSION_DENIED',
          isRetryable: false,
        );
}

class ChecksumValidationException extends ModuleException {
  ChecksumValidationException(
    String path,
    String expected,
    String actual, {
    String? moduleId,
    String? correlationId,
  }) : super(
          'Checksum validation failed for $path\nExpected: $expected\nActual: $actual',
          severity: ErrorSeverity.high,
          category: ErrorCategory.validation,
          context: ErrorContext(
            operation: 'checksum_validation',
            moduleId: moduleId,
            correlationId: correlationId,
            metadata: {
              'path': path,
              'expected': expected,
              'actual': actual,
            },
          ),
          errorCode: 'CHECKSUM_VALIDATION_FAILED',
          isRetryable: true,
          retryAfter: const Duration(seconds: 5),
        );
}

class FormatValidationException extends ModuleException {
  FormatValidationException(
    String path,
    String format, {
    dynamic cause,
    String? moduleId,
    String? correlationId,
  }) : super(
          'Format validation failed for $path: $format',
          cause: cause,
          severity: ErrorSeverity.medium,
          category: ErrorCategory.validation,
          context: ErrorContext(
            operation: 'format_validation',
            moduleId: moduleId,
            correlationId: correlationId,
            metadata: {
              'path': path,
              'format': format,
            },
          ),
          errorCode: 'FORMAT_VALIDATION_FAILED',
          isRetryable: false,
        );
}

class CommandExecutionException extends ModuleException {
  CommandExecutionException(
    String command, {
    dynamic cause,
    StackTrace? stackTrace,
    String? moduleId,
    String? correlationId,
    int? exitCode,
  }) : super(
          'Command execution failed: $command',
          cause: cause,
          stackTrace: stackTrace,
          severity: ErrorSeverity.medium,
          category: ErrorCategory.execution,
          context: ErrorContext(
            operation: 'command_execution',
            moduleId: moduleId,
            correlationId: correlationId,
            metadata: {
              'command': command,
              'exitCode': exitCode,
            },
          ),
          errorCode: 'COMMAND_EXECUTION_FAILED',
          isRetryable: true,
          retryAfter: const Duration(seconds: 10),
        );
}

class SymlinkCreationException extends ModuleException {
  SymlinkCreationException(
    String path, {
    dynamic cause,
    String? moduleId,
    String? correlationId,
  }) : super(
          'Failed to create symlink: $path',
          cause: cause,
          severity: ErrorSeverity.medium,
          category: ErrorCategory.fileSystem,
          context: ErrorContext(
            operation: 'symlink_creation',
            moduleId: moduleId,
            correlationId: correlationId,
            metadata: {'path': path},
          ),
          errorCode: 'SYMLINK_CREATION_FAILED',
          isRetryable: true,
          retryAfter: const Duration(seconds: 2),
        );
}

class ConfigurationFailedException extends ModuleException {
  final List<ModuleException> errors;

  ConfigurationFailedException(
    this.errors, {
    String? moduleId,
    String? correlationId,
  }) : super(
          'Multiple configuration errors occurred:\n${errors.map((e) => '- ${e.message}').join('\n')}',
          severity: ErrorSeverity.critical,
          category: ErrorCategory.configuration,
          context: ErrorContext(
            operation: 'configuration_validation',
            moduleId: moduleId,
            correlationId: correlationId,
            metadata: {
              'errorCount': errors.length,
              'errors': errors.map((e) => e.toStructuredData()).toList(),
            },
          ),
          errorCode: 'CONFIGURATION_FAILED',
          isRetryable: false,
        );
}
