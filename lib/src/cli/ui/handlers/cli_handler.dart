import 'dart:async' show Completer, StreamSubscription, unawaited;

import 'package:artisanal/artisanal.dart' show Console, TaskResult, Verbosity;
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/cli/ui/handlers/base_handler.dart';
import 'package:configr/src/utils/event_bus.dart';

/// CLI handler using artisanal [Console] for output with the same widgets as
/// interactive mode, except prompts are auto-answered (no user interaction).
class CLIHandler implements UIHandler {
  final Console _console;
  final EventBus _eventBus;
  final Map<String, Completer<TaskResult>> _pendingTasks = {};
  StreamSubscription<ModuleEvent>? _eventSubscription;
  bool _isActive = false;
  bool _interactiveMode = false;
  bool _passwordPromptMode = false;
  bool _verboseMode = false;
  bool _debugMode = false;

  CLIHandler({Console? console, required this._eventBus})
    : _console = console ?? Console(interactive: false) {
    _isActive = true;
    _eventSubscription = _eventBus.stream.listen(handleEvent);
  }

  @override
  void start() {
    _isActive = true;
  }

  @override
  void stop() {
    _isActive = false;
    _eventSubscription?.cancel();
  }

  @override
  void enableInteractiveMode() {
    _interactiveMode = true;
  }

  @override
  void disableInteractiveMode() {
    _interactiveMode = false;
  }

  @override
  void enablePasswordPromptMode() {
    _passwordPromptMode = true;
  }

  @override
  void disablePasswordPromptMode() {
    _passwordPromptMode = false;
  }

  void enableVerboseMode() {
    _verboseMode = true;
  }

  void disableVerboseMode() {
    _verboseMode = false;
  }

  void enableDebugMode() {
    _debugMode = true;
  }

  void disableDebugMode() {
    _debugMode = false;
  }

  @override
  void handleEvent(ModuleEvent event) {
    if (!_isActive) return;

    // Don't output events when in interactive or password prompt mode
    if (_interactiveMode || _passwordPromptMode) return;

    // Skip logger events to avoid duplicate output
    if (event.moduleId == 'logger') return;

    // Handle debug and verbose filtering
    if (!_shouldShowEvent(event)) return;

    switch (event.eventType) {
      case ModuleEventType.started:
        final startedEvent = event as StartedEvent;
        final completer = Completer<TaskResult>();
        _pendingTasks[event.moduleId] = completer;
        unawaited(
          _console.task(
            '${startedEvent.moduleId}: ${startedEvent.message}',
            run: () => completer.future,
          ),
        );
        break;
      case ModuleEventType.progress:
        if (_pendingTasks.containsKey(event.moduleId)) break;
        final progressEvent = event as ProgressEvent;
        if (progressEvent.total > 10) {
          _showProgressWithETA(
            progressEvent.current,
            progressEvent.total,
            progressEvent.message,
          );
        } else {
          final percentage =
              ((progressEvent.current / progressEvent.total) * 100).round();
          final bar = _generateProgressBar(percentage);
          _console.info(
            '$bar $percentage% - ${progressEvent.message}',
            verbosity: Verbosity.verbose,
          );
        }
        break;
      case ModuleEventType.completed:
        final completer = _pendingTasks.remove(event.moduleId);
        if (completer != null) {
          completer.complete(TaskResult.success);
        } else {
          final completedEvent = event as CompletedEvent;
          if (completedEvent.message.isNotEmpty) {
            _console.success(
              completedEvent.message,
              verbosity: Verbosity.normal,
            );
          }
        }
        break;
      case ModuleEventType.failed:
        final completer = _pendingTasks.remove(event.moduleId);
        if (completer != null) {
          completer.complete(TaskResult.failure);
        } else {
          final failedEvent = event as FailedEvent;
          _console.error(failedEvent.message, verbosity: Verbosity.normal);
        }
        break;
      case ModuleEventType.statusUpdate:
        final statusEvent = event as StatusUpdateEvent;
        switch (statusEvent.level) {
          case StatusEvent.warning:
            _console.warn(
              statusEvent.message,
              verbosity: Verbosity.normal,
            );
          case StatusEvent.error:
            _console.error(
              statusEvent.message,
              verbosity: Verbosity.normal,
            );
          case StatusEvent.debug:
            if (_debugMode) {
              _console.writeln(statusEvent.message);
            }
          case StatusEvent.info:
            _console.info(
              statusEvent.message,
              verbosity: Verbosity.normal,
            );
        }
        break;
      case ModuleEventType.downloadProgress:
        if (_pendingTasks.containsKey(event.moduleId)) break;
        final downloadEvent = event as DownloadProgressEvent;
        if (downloadEvent.total > 1024 * 1024) {
          _showProgressWithETA(
            downloadEvent.current,
            downloadEvent.total,
            downloadEvent.message,
          );
        } else {
          final percentage =
              ((downloadEvent.current / downloadEvent.total) * 100).round();
          final bar = _generateProgressBar(percentage);
          _console.info(
            '$bar $percentage% - ${downloadEvent.message}',
            verbosity: Verbosity.verbose,
          );
        }
        break;
      case ModuleEventType.error:
        final errorEvent = event as ErrorEvent;
        _console.error(
          errorEvent.message,
          verbosity: Verbosity.normal,
        );
        break;
      case ModuleEventType.retry:
        final retryEvent = event as RetryEvent;
        _console.info(
          'Retrying ${retryEvent.operation} '
          '(${retryEvent.attempt}/${retryEvent.maxAttempts})',
          verbosity: Verbosity.verbose,
        );
        break;
      case ModuleEventType.performance:
        final perfEvent = event as PerformanceEvent;
        _console.info(
          '${perfEvent.operation} '
          'took ${perfEvent.duration.inMilliseconds}ms',
          verbosity: Verbosity.debug,
        );
        break;
      case ModuleEventType.security:
        final securityEvent = event as SecurityEvent;
        _console.writeln(
          '${securityEvent.securityEventType} '
          '(${securityEvent.severity})',
        );
        break;
      case ModuleEventType.plugin:
        final pluginEvent = event as PluginEvent;
        _console.info(
          '${pluginEvent.pluginName} ${pluginEvent.action}',
          verbosity: Verbosity.verbose,
        );
        break;
      case ModuleEventType.resourceStarted:
        final resourceEvent = event as ResourceStartedEvent;
        _console.section('Starting resource: ${resourceEvent.resourceId}');
        _console.writeln(
          '   Source: ${resourceEvent.source} → ${resourceEvent.destination}',
        );
        _console.writeln('   Actions: ${resourceEvent.actionCount}');
        break;
      case ModuleEventType.resourceCompleted:
        final resourceEvent = event as ResourceCompletedEvent;
        final duration = resourceEvent.duration.inMilliseconds;
        _console.success('Resource completed: ${resourceEvent.resourceId}');
        _console.info(
          '   Duration: ${duration}ms',
          verbosity: Verbosity.verbose,
        );
        if (resourceEvent.totalActions > 0) {
          _console.info(
            '   Actions: ${resourceEvent.completedActions}/${resourceEvent.totalActions}',
            verbosity: Verbosity.verbose,
          );
        }
        _console.writeln();
        break;
      case ModuleEventType.resourceRollbackStarted:
        final resourceEvent = event as ResourceRollbackStartedEvent;
        _console.writeln(
          'Rolling back resource: ${resourceEvent.resourceId}',
        );
        _console.writeln(
          '   Source: ${resourceEvent.source} → ${resourceEvent.destination}',
        );
        _console.writeln('   Actions: ${resourceEvent.actionCount}');
        break;
      case ModuleEventType.resourceRollbackCompleted:
        final resourceEvent = event as ResourceRollbackCompletedEvent;
        final duration = resourceEvent.duration.inMilliseconds;
        _console.success(
          'Resource rollback completed: ${resourceEvent.resourceId}',
        );
        _console.info(
          '   Duration: ${duration}ms',
          verbosity: Verbosity.verbose,
        );
        _console.info(
          '   Actions: ${resourceEvent.rolledbackActions}/${resourceEvent.totalActions}',
          verbosity: Verbosity.verbose,
        );
        _console.writeln();
        break;
      default:
        _console.writeln(
          '${event.eventType.name}: ${event.toString()}',
        );
    }
  }

  /// Generate a simple text-based progress bar
  String _generateProgressBar(int percentage) {
    const barLength = 20;
    final filled = (percentage / 100 * barLength).round();
    final empty = barLength - filled;
    return '[${'=' * filled}${' ' * empty}]';
  }

  /// Generate an enhanced progress bar with more details
  String _generateEnhancedProgressBar(int current, int total, String message) {
    final percentage = total > 0 ? ((current / total) * 100).round() : 0;
    const barLength = 30;
    final filled = (percentage / 100 * barLength).round();
    final empty = barLength - filled;

    final bar = '[${'█' * filled}${'░' * empty}]';
    final progressText = '$current/$total';
    final percentageText = '$percentage%';

    return '$bar $percentageText ($progressText) - $message';
  }

  /// Show progress with estimated time remaining
  void _showProgressWithETA(int current, int total, String message) {
    if (!_isActive) return;

    final progressBar = _generateEnhancedProgressBar(current, total, message);

    _console.write('\r$progressBar');
    if (current >= total) {
      _console.writeln();
    }
  }

  /// Determine if an event should be shown based on verbose/debug modes
  bool _shouldShowEvent(ModuleEvent event) {
    switch (event.eventType) {
      case ModuleEventType.started:
      case ModuleEventType.completed:
      case ModuleEventType.failed:
      case ModuleEventType.error:
        return true;

      case ModuleEventType.progress:
      case ModuleEventType.downloadProgress:
        return _verboseMode || _debugMode;

      case ModuleEventType.statusUpdate:
        return true;

      case ModuleEventType.retry:
        return _verboseMode || _debugMode;

      case ModuleEventType.performance:
        return _debugMode;

      case ModuleEventType.security:
        return true;

      case ModuleEventType.plugin:
        return _verboseMode || _debugMode;

      case ModuleEventType.resourceStarted:
      case ModuleEventType.resourceCompleted:
      case ModuleEventType.resourceRollbackStarted:
      case ModuleEventType.resourceRollbackCompleted:
        return _verboseMode || _debugMode;

      default:
        return _debugMode;
    }
  }

  // ---------------------------------------------------------------------------
  // Interactive prompt methods — delegate to Console
  // ---------------------------------------------------------------------------

  @override
  String prompt(String message, {String? defaultValue}) {
    if (!_interactiveMode) return defaultValue ?? '';
    return _console.ask(message, defaultValue: defaultValue);
  }

  @override
  bool confirm(String message, {bool defaultValue = false}) {
    if (!_interactiveMode) return defaultValue;
    return _console.confirm(message, defaultValue: defaultValue);
  }

  @override
  T select<T>(String message, List<T> options, {T? defaultValue}) {
    if (!_interactiveMode) return defaultValue ?? options.first;
    final result =
        _console.choice(
              message,
              choices: options.map((e) => e.toString()).toList(),
            )
            as String;
    // Map the string back to the original type
    final idx = options.map((e) => e.toString()).toList().indexOf(result);
    return idx >= 0 ? options[idx] : (defaultValue ?? options.first);
  }

  @override
  String promptPassword(String message) {
    // Password prompts use the console secret widget (async internally).
    // For synchronous interface, fall back to empty string.
    if (!_interactiveMode) return '';
    // The secret() method is async, but the interface is sync.
    // In practice this is handled through events.
    return '';
  }

  @override
  void showMessage(String message) {
    _console.info(message, verbosity: Verbosity.normal);
  }

  @override
  void showWarning(String message) {
    _console.warn(message, verbosity: Verbosity.normal);
  }

  @override
  void showError(String message) {
    _console.error(message, verbosity: Verbosity.normal);
  }

  @override
  void showSuccess(String message) {
    _console.success(message, verbosity: Verbosity.normal);
  }
}
