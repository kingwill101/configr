import 'dart:async';
import 'dart:math';

import 'package:configr/src/exceptions.dart';

/// Retry configuration for operations
class RetryConfig {
  final int maxAttempts;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final Duration? timeout;
  final bool Function(ModuleException)? shouldRetry;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    this.timeout,
    this.shouldRetry,
  });

  /// Default retry configuration for network operations
  static const RetryConfig network = RetryConfig(
    maxAttempts: 3,
    initialDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 30),
    backoffMultiplier: 2.0,
    timeout: Duration(minutes: 5),
  );

  /// Default retry configuration for file operations
  static const RetryConfig fileOperation = RetryConfig(
    maxAttempts: 2,
    initialDelay: Duration(milliseconds: 500),
    maxDelay: Duration(seconds: 10),
    backoffMultiplier: 1.5,
  );

  /// Default retry configuration for command execution
  static const RetryConfig commandExecution = RetryConfig(
    maxAttempts: 2,
    initialDelay: Duration(seconds: 2),
    maxDelay: Duration(seconds: 15),
    backoffMultiplier: 2.0,
    timeout: Duration(minutes: 10),
  );
}

/// Result of a retry operation
class RetryResult<T> {
  final T? value;
  final ModuleException? lastException;
  final int attempts;
  final bool succeeded;

  const RetryResult._({
    this.value,
    this.lastException,
    required this.attempts,
    required this.succeeded,
  });

  factory RetryResult.success(T value, int attempts) {
    return RetryResult._(
      value: value,
      attempts: attempts,
      succeeded: true,
    );
  }

  factory RetryResult.failure(ModuleException exception, int attempts) {
    return RetryResult._(
      lastException: exception,
      attempts: attempts,
      succeeded: false,
    );
  }
}

/// Handles retry logic for operations that may fail
class RetryHandler {
  static final Random _random = Random();

  /// Execute an operation with retry logic
  static Future<RetryResult<T>> execute<T>(
    Future<T> Function() operation, {
    RetryConfig config = const RetryConfig(),
    String? operationName,
    String? moduleId,
    String? correlationId,
  }) async {
    ModuleException? lastException;
    int attempts = 0;

    for (int attempt = 1; attempt <= config.maxAttempts; attempt++) {
      attempts = attempt;
      
      try {
        final result = await _executeWithTimeout(
          operation,
          config.timeout,
        );
        
        return RetryResult.success(result, attempts);
      } catch (e) {
        lastException = _wrapException(e, operationName, moduleId, correlationId);
        
        // Check if we should retry this exception
        if (!_shouldRetry(lastException, config, attempt)) {
          break;
        }
        
        // Wait before retrying (except on last attempt)
        if (attempt < config.maxAttempts) {
          final delay = _calculateDelay(attempt, config);
          await Future.delayed(delay);
        }
      }
    }

    return RetryResult.failure(lastException!, attempts);
  }

  /// Execute an operation with timeout
  static Future<T> _executeWithTimeout<T>(
    Future<T> Function() operation,
    Duration? timeout,
  ) async {
    if (timeout == null) {
      return await operation();
    }

    return await operation().timeout(timeout);
  }

  /// Wrap any exception in a ModuleException if needed
  static ModuleException _wrapException(
    dynamic exception,
    String? operationName,
    String? moduleId,
    String? correlationId,
  ) {
    if (exception is ModuleException) {
      return exception;
    }

    return ActionFailedException(
      'Operation failed: ${exception.toString()}',
      cause: exception,
      moduleId: moduleId,
      correlationId: correlationId,
    );
  }

  /// Determine if an exception should be retried
  static bool _shouldRetry(
    ModuleException exception,
    RetryConfig config,
    int attempt,
  ) {
    // Don't retry if we've exceeded max attempts
    if (attempt >= config.maxAttempts) {
      return false;
    }

    // Don't retry if the exception is not retryable
    if (!exception.isRetryable) {
      return false;
    }

    // Use custom retry logic if provided
    if (config.shouldRetry != null) {
      return config.shouldRetry!(exception);
    }

    // Default retry logic based on error category
    switch (exception.category) {
      case ErrorCategory.network:
      case ErrorCategory.execution:
        return true;
      case ErrorCategory.fileSystem:
        // Retry file system errors that might be temporary
        return exception.errorCode == 'PERMISSION_DENIED' ||
               exception.errorCode == 'ACTION_FAILED';
      case ErrorCategory.validation:
        // Don't retry validation errors
        return false;
      case ErrorCategory.permission:
        // Don't retry permission errors
        return false;
      case ErrorCategory.configuration:
        // Don't retry configuration errors
        return false;
      case ErrorCategory.security:
        // Don't retry security errors
        return false;
      case ErrorCategory.performance:
        // Retry performance-related errors
        return true;
      case ErrorCategory.unknown:
        // Retry unknown errors by default
        return true;
    }
  }

  /// Calculate delay for next retry attempt
  static Duration _calculateDelay(int attempt, RetryConfig config) {
    // Exponential backoff with jitter
    final baseDelay = config.initialDelay.inMilliseconds * 
        pow(config.backoffMultiplier, attempt - 1);
    
    // Add jitter (±25% random variation)
    final jitter = baseDelay * 0.25 * (_random.nextDouble() * 2 - 1);
    final delayMs = (baseDelay + jitter).round();
    
    // Cap at max delay
    final cappedDelay = min(delayMs, config.maxDelay.inMilliseconds);
    
    return Duration(milliseconds: cappedDelay);
  }

  /// Execute multiple operations in parallel with retry logic
  static Future<List<RetryResult<T>>> executeParallel<T>(
    List<Future<T> Function()> operations, {
    RetryConfig config = const RetryConfig(),
    String? operationName,
    String? moduleId,
    String? correlationId,
  }) async {
    final futures = operations.map((operation) => execute(
      operation,
      config: config,
      operationName: operationName,
      moduleId: moduleId,
      correlationId: correlationId,
    ));

    return await Future.wait(futures);
  }

  /// Execute operations sequentially with retry logic
  static Future<List<RetryResult<T>>> executeSequential<T>(
    List<Future<T> Function()> operations, {
    RetryConfig config = const RetryConfig(),
    String? operationName,
    String? moduleId,
    String? correlationId,
    bool stopOnFirstFailure = false,
  }) async {
    final results = <RetryResult<T>>[];

    for (int i = 0; i < operations.length; i++) {
      final result = await execute(
        operations[i],
        config: config,
        operationName: '$operationName[$i]',
        moduleId: moduleId,
        correlationId: correlationId,
      );

      results.add(result);

      // Stop on first failure if configured
      if (stopOnFirstFailure && !result.succeeded) {
        break;
      }
    }

    return results;
  }
}
