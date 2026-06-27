import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/utils/event_bus.dart' show EventBus;

/// Extension methods for EventBus to support multi-host execution.
extension ExecutionEventBusExtension on EventBus {
  /// Get the execution ID for the current multi-host operation.
  String get executionId => 'exec_${DateTime.now().millisecondsSinceEpoch}';

  /// Emit a host-started event with automatic correlation.
  void emitHostStarted(String hostName, {Map<String, dynamic>? metadata}) {
    emit(
      StartedEvent(
        moduleId: hostName,
        message: 'Host execution started',
        correlationId: executionId,
        metadata: metadata,
      ),
    );
  }

  /// Emit a host-completed event with automatic correlation.
  void emitHostCompleted(String hostName, {Duration? duration, Map<String, dynamic>? metadata}) {
    emit(
      CompletedEvent(
        moduleId: hostName,
        message: 'Host execution completed',
        duration: duration ?? Duration.zero,
        correlationId: executionId,
        metadata: metadata,
      ),
    );
  }

  /// Emit a host-failed event with automatic correlation.
  void emitHostFailed(String hostName, dynamic error, {Map<String, dynamic>? metadata}) {
    emit(
      FailedEvent(
        moduleId: hostName,
        message: 'Host execution failed',
        errorCode: 'HOST_EXECUTION_FAILED',
        cause: error,
        correlationId: executionId,
        metadata: metadata,
      ),
    );
  }

  /// Emit a status update with automatic correlation.
  void emitStatusUpdate(String moduleId, String message, {StatusEvent level = StatusEvent.info, Map<String, dynamic>? metadata}) {
    emit(
      StatusUpdateEvent(
        moduleId: moduleId,
        level: level,
        message: message,
        correlationId: executionId,
        metadata: metadata,
      ),
    );
  }
}