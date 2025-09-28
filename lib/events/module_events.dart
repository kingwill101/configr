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
}

/// Sealed base class (only extendable in this library).
sealed class ModuleEvent {
  final String moduleId;

  const ModuleEvent({this.moduleId = 'default'});
}

class StartedEvent extends ModuleEvent {
  final String message;

  const StartedEvent({
    super.moduleId,
    required this.message,
  });
}

class ProgressEvent extends ModuleEvent {
  final int current;
  final int total;
  final String message;

  const ProgressEvent({
    super.moduleId,
    this.current = 0,
    this.total = 100,
    this.message = '',
  });
}

class CompletedEvent extends ModuleEvent {
  final String message;

  const CompletedEvent({
    super.moduleId,
    required this.message,
  });
}

class StatusUpdateEvent extends ModuleEvent {
  final StatusEvent level;
  final String message;

  const StatusUpdateEvent({
    super.moduleId,
    required this.level,
    required this.message,
  });
}

enum StatusEvent {
  info,
  warning,
  error,
  debug,
}

class FailedEvent extends ModuleEvent {
  final String message;

  const FailedEvent({
    super.moduleId,
    required this.message,
  });
}

class DownloadProgressEvent extends ModuleEvent {
  final int current;
  final int total;
  final String message;

  const DownloadProgressEvent({
    super.moduleId,
    this.current = 0,
    this.total = 100,
    this.message = '',
  });
}
