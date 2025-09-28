enum ModuleEventType {
  started,
  progress,
  completed,
  failed,
  requiresInput,
  statusUpdate,
  downloadProgress,
  fileOperation,
  validation,
  execution,
  error,
  warning,
  info,
  debug,
  retry,
  timeout,
  security,
  performance,
  configuration,
  plugin,
  network,
  fileSystem,
}

/// Sealed base class (only extendable in this library).
sealed class ModuleEvent {
  final String moduleId;
  final String? correlationId;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  ModuleEvent({
    this.moduleId = 'default',
    this.correlationId,
    DateTime? timestamp,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Get the event type
  ModuleEventType get eventType;

  /// Convert to structured data for logging/monitoring
  Map<String, dynamic> toStructuredData() {
    return {
      'eventType': eventType.name,
      'moduleId': moduleId,
      'correlationId': correlationId,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }
}

class StartedEvent extends ModuleEvent {
  final String message;

  StartedEvent({
    super.moduleId,
    super.correlationId,
    super.timestamp,
    super.metadata,
    required this.message,
  });

  @override
  ModuleEventType get eventType => ModuleEventType.started;

  @override
  Map<String, dynamic> toStructuredData() {
    final data = super.toStructuredData();
    data['message'] = message;
    return data;
  }
}

class ProgressEvent extends ModuleEvent {
  final int current;
  final int total;
  final String message;

  ProgressEvent({
    super.moduleId,
    super.correlationId,
    super.timestamp,
    super.metadata,
    this.current = 0,
    this.total = 100,
    this.message = '',
  });

  @override
  ModuleEventType get eventType => ModuleEventType.progress;

  @override
  Map<String, dynamic> toStructuredData() {
    final data = super.toStructuredData();
    data['current'] = current;
    data['total'] = total;
    data['message'] = message;
    data['percentage'] = total > 0 ? (current / total * 100).round() : 0;
    return data;
  }
}

class CompletedEvent extends ModuleEvent {
  final String message;
  final Duration? duration;

  CompletedEvent({
    super.moduleId,
    super.correlationId,
    super.timestamp,
    super.metadata,
    required this.message,
    this.duration,
  });

  @override
  ModuleEventType get eventType => ModuleEventType.completed;

  @override
  Map<String, dynamic> toStructuredData() {
    final data = super.toStructuredData();
    data['message'] = message;
    if (duration != null) {
      data['duration'] = duration!.inMilliseconds;
    }
    return data;
  }
}

class StatusUpdateEvent extends ModuleEvent {
  final StatusEvent level;
  final String message;

  StatusUpdateEvent({
    super.moduleId,
    super.correlationId,
    super.timestamp,
    super.metadata,
    required this.level,
    required this.message,
  });

  @override
  ModuleEventType get eventType => ModuleEventType.statusUpdate;

  @override
  Map<String, dynamic> toStructuredData() {
    final data = super.toStructuredData();
    data['level'] = level.name;
    data['message'] = message;
    return data;
  }
}

enum StatusEvent {
  info,
  warning,
  error,
  debug,
}

class FailedEvent extends ModuleEvent {
  final String message;
  final String? errorCode;
  final dynamic cause;

  FailedEvent({
    super.moduleId,
    super.correlationId,
    super.timestamp,
    super.metadata,
    required this.message,
    this.errorCode,
    this.cause,
  });

  @override
  ModuleEventType get eventType => ModuleEventType.failed;

  @override
  Map<String, dynamic> toStructuredData() {
    final data = super.toStructuredData();
    data['message'] = message;
    data['errorCode'] = errorCode;
    data['cause'] = cause?.toString();
    return data;
  }
}

class DownloadProgressEvent extends ModuleEvent {
  final int current;
  final int total;
  final String message;
  final String? url;

  DownloadProgressEvent({
    super.moduleId,
    super.correlationId,
    super.timestamp,
    super.metadata,
    this.current = 0,
    this.total = 100,
    this.message = '',
    this.url,
  });

  @override
  ModuleEventType get eventType => ModuleEventType.downloadProgress;

  @override
  Map<String, dynamic> toStructuredData() {
    final data = super.toStructuredData();
    data['current'] = current;
    data['total'] = total;
    data['message'] = message;
    data['url'] = url;
    data['percentage'] = total > 0 ? (current / total * 100).round() : 0;
    return data;
  }
}

/// Error event for structured error reporting
class ErrorEvent extends ModuleEvent {
  final String errorCode;
  final String message;
  final String severity;
  final String category;
  final bool isRetryable;
  final Duration? retryAfter;
  final dynamic cause;

  ErrorEvent({
    super.moduleId,
    super.correlationId,
    super.timestamp,
    super.metadata,
    required this.errorCode,
    required this.message,
    required this.severity,
    required this.category,
    this.isRetryable = false,
    this.retryAfter,
    this.cause,
  });

  @override
  ModuleEventType get eventType => ModuleEventType.error;

  @override
  Map<String, dynamic> toStructuredData() {
    final data = super.toStructuredData();
    data['errorCode'] = errorCode;
    data['message'] = message;
    data['severity'] = severity;
    data['category'] = category;
    data['isRetryable'] = isRetryable;
    data['retryAfter'] = retryAfter?.inSeconds;
    data['cause'] = cause?.toString();
    return data;
  }
}

/// Retry event for retry operations
class RetryEvent extends ModuleEvent {
  final int attempt;
  final int maxAttempts;
  final String operation;
  final Duration delay;
  final String? reason;

  RetryEvent({
    super.moduleId,
    super.correlationId,
    super.timestamp,
    super.metadata,
    required this.attempt,
    required this.maxAttempts,
    required this.operation,
    required this.delay,
    this.reason,
  });

  @override
  ModuleEventType get eventType => ModuleEventType.retry;

  @override
  Map<String, dynamic> toStructuredData() {
    final data = super.toStructuredData();
    data['attempt'] = attempt;
    data['maxAttempts'] = maxAttempts;
    data['operation'] = operation;
    data['delay'] = delay.inMilliseconds;
    data['reason'] = reason;
    return data;
  }
}

/// Performance event for performance monitoring
class PerformanceEvent extends ModuleEvent {
  final String operation;
  final Duration duration;
  final Map<String, dynamic>? metrics;

  PerformanceEvent({
    super.moduleId,
    super.correlationId,
    super.timestamp,
    super.metadata,
    required this.operation,
    required this.duration,
    this.metrics,
  });

  @override
  ModuleEventType get eventType => ModuleEventType.performance;

  @override
  Map<String, dynamic> toStructuredData() {
    final data = super.toStructuredData();
    data['operation'] = operation;
    data['duration'] = duration.inMilliseconds;
    data['metrics'] = metrics;
    return data;
  }
}

/// Security event for security monitoring
class SecurityEvent extends ModuleEvent {
  final String securityEventType;
  final String severity;
  final String? userId;
  final String? resource;
  final Map<String, dynamic>? details;

  SecurityEvent({
    super.moduleId,
    super.correlationId,
    super.timestamp,
    super.metadata,
    required this.securityEventType,
    required this.severity,
    this.userId,
    this.resource,
    this.details,
  });

  @override
  ModuleEventType get eventType => ModuleEventType.security;

  @override
  Map<String, dynamic> toStructuredData() {
    final data = super.toStructuredData();
    data['securityEventType'] = securityEventType;
    data['severity'] = severity;
    data['userId'] = userId;
    data['resource'] = resource;
    data['details'] = details;
    return data;
  }
}

/// Plugin event for plugin system
class PluginEvent extends ModuleEvent {
  final String pluginName;
  final String action;
  final String? version;
  final Map<String, dynamic>? details;

  PluginEvent({
    super.moduleId,
    super.correlationId,
    super.timestamp,
    super.metadata,
    required this.pluginName,
    required this.action,
    this.version,
    this.details,
  });

  @override
  ModuleEventType get eventType => ModuleEventType.plugin;

  @override
  Map<String, dynamic> toStructuredData() {
    final data = super.toStructuredData();
    data['pluginName'] = pluginName;
    data['action'] = action;
    data['version'] = version;
    data['details'] = details;
    return data;
  }
}
