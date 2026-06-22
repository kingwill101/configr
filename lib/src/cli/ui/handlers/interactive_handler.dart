import 'dart:async' show Completer, unawaited;
import 'dart:io' as dart_io;

import 'package:artisanal/artisanal.dart' show Console, TaskResult;
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/cli/ui/handlers/base_handler.dart';
import 'package:configr/src/utils/event_bus.dart';

/// Interactive UI handler that uses artisanal [Console] for styled output
/// and coordinates user input through the event bus.
class InteractiveHandler implements UIHandler {
  final Console _console;
  EventBus _eventBus;
  final bool _debugMode;
  final bool _interactiveMode;
  final Map<String, Completer<TaskResult>> _pendingTasks = {};

  InteractiveHandler({
    required EventBus eventBus,
    Console? console,
    bool verboseMode = false,
    bool debugMode = false,
    bool interactiveMode = true,
  }) : _eventBus = eventBus,
       _console = console ?? Console(interactive: interactiveMode),
       _debugMode = debugMode,
       _interactiveMode = interactiveMode {
    _setupEventListeners();
  }

  void _setupEventListeners() {
    _eventBus.stream.listen((event) {
      if (event is UserInputRequiredEvent) {
        _handleUserInputRequired(event);
      } else if (event is WaitForUserEvent) {
        _handleWaitForUser(event);
      } else {
        _handleRegularEvent(event);
      }
    });
  }

  void _handleUserInputRequired(UserInputRequiredEvent event) {
    if (!_interactiveMode) {
      // In non-interactive mode, use default value or first option
      final input =
          event.defaultValue ??
          (event.options?.isNotEmpty == true ? event.options!.first : '');
      _eventBus.emit(
        UserInputReceivedEvent(
          moduleId: event.moduleId,
          correlationId: event.correlationId,
          input: input,
          inputType: event.inputType,
        ),
      );
      return;
    }

    // In interactive mode, prompt for input
    _promptForInput(event);
  }

  void _handleWaitForUser(WaitForUserEvent event) {
    if (_interactiveMode) {
      _console.writeln('\n⏸️  Waiting for user input: ${event.reason}');
      _console.info('Press Enter to continue...');
      dart_io.stdin.readLineSync();
      _eventBus.emit(
        ResumeProcessingEvent(
          moduleId: event.moduleId,
          correlationId: event.correlationId,
        ),
      );
    }
  }

  void _handleRegularEvent(ModuleEvent event) {
    // Handle regular events with proper formatting
    if (event is StatusUpdateEvent) {
      _handleStatusUpdate(event);
    } else if (event is ProgressEvent) {
      _handleProgress(event);
    } else if (event is DownloadProgressEvent) {
      _handleDownloadProgress(event);
    } else if (event is StartedEvent) {
      _handleStarted(event);
    } else if (event is CompletedEvent) {
      _handleCompleted(event);
    } else if (event is FailedEvent) {
      _handleFailed(event);
    } else if (event is ErrorEvent) {
      _handleError(event);
    } else if (event is ResourceStartedEvent) {
      _handleResourceStarted(event);
    } else if (event is ResourceCompletedEvent) {
      _handleResourceCompleted(event);
    } else if (event is ResourceRollbackStartedEvent) {
      _handleResourceRollbackStarted(event);
    } else if (event is ResourceRollbackCompletedEvent) {
      _handleResourceRollbackCompleted(event);
    } else if (_debugMode) {
      _console.writeln(
        '🔍 [DEBUG] ${event.runtimeType}: ${event.toStructuredData()}',
      );
    }
  }

  void _promptForInput(UserInputRequiredEvent event) {
    final correlationId =
        event.correlationId ?? DateTime.now().millisecondsSinceEpoch.toString();

    switch (event.inputType) {
      case 'text':
        _promptText(event, correlationId);
        break;
      case 'password':
        _promptPassword(event, correlationId);
        break;
      case 'confirm':
        _promptConfirm(event, correlationId);
        break;
      case 'select':
        _promptSelect(event, correlationId);
        break;
      default:
        _promptText(event, correlationId);
    }
  }

  void _promptText(UserInputRequiredEvent event, String correlationId) {
    final result = _console.ask(event.prompt, defaultValue: event.defaultValue);

    _eventBus.emit(
      UserInputReceivedEvent(
        moduleId: event.moduleId,
        correlationId: correlationId,
        input: result,
        inputType: event.inputType,
      ),
    );
  }

  void _promptPassword(UserInputRequiredEvent event, String correlationId) {
    // For password prompts we use dart:io stdin directly since
    // the async secret() doesn't fit the event-driven flow here.
    dart_io.stdout.write('${event.prompt}: ');
    dart_io.stdin.echoMode = false;
    final password = dart_io.stdin.readLineSync() ?? '';
    dart_io.stdin.echoMode = true;
    _console.writeln(); // newline after hidden input

    _eventBus.emit(
      UserInputReceivedEvent(
        moduleId: event.moduleId,
        correlationId: correlationId,
        input: password,
        inputType: event.inputType,
      ),
    );
  }

  void _promptConfirm(UserInputRequiredEvent event, String correlationId) {
    final defaultVal = event.defaultValue == 'true';
    final result = _console.confirm(event.prompt, defaultValue: defaultVal);

    _eventBus.emit(
      UserInputReceivedEvent(
        moduleId: event.moduleId,
        correlationId: correlationId,
        input: result ? 'true' : 'false',
        inputType: event.inputType,
      ),
    );
  }

  void _promptSelect(UserInputRequiredEvent event, String correlationId) {
    if (event.options == null || event.options!.isEmpty) {
      _eventBus.emit(
        UserInputReceivedEvent(
          moduleId: event.moduleId,
          correlationId: correlationId,
          input: event.defaultValue ?? '',
          inputType: event.inputType,
        ),
      );
      return;
    }

    final defaultIdx = event.defaultValue != null
        ? event.options!.indexOf(event.defaultValue!)
        : null;
    final result = _console.choice(
      event.prompt,
      choices: event.options!,
      defaultIndex: defaultIdx != null && defaultIdx >= 0 ? defaultIdx : null,
    );

    _eventBus.emit(
      UserInputReceivedEvent(
        moduleId: event.moduleId,
        correlationId: correlationId,
        input: result.toString(),
        inputType: event.inputType,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Event display methods — all use artisanal Console
  // ---------------------------------------------------------------------------

  void _handleStatusUpdate(StatusUpdateEvent event) {
    switch (event.level) {
      case StatusEvent.info:
        _console.info(event.message);
      case StatusEvent.warning:
        _console.warn(event.message);
      case StatusEvent.error:
        _console.error(event.message);
      case StatusEvent.debug:
        if (_debugMode) {
          _console.writeln(event.message);
        }
    }
  }

  void _handleProgress(ProgressEvent event) {
    if (_pendingTasks.containsKey(event.moduleId)) return;
    if (event.total > 0) {
      final percentage = (event.current / event.total * 100).round();
      final bar = _generateProgressBar(event.current, event.total);
      _console.write('\r$bar $percentage% ${event.message}');
      if (event.current >= event.total) {
        _console.writeln();
      }
    } else {
      _console.info(event.message);
    }
  }

  void _handleDownloadProgress(DownloadProgressEvent event) {
    if (_pendingTasks.containsKey(event.moduleId)) return;
    if (event.total > 0) {
      final percentage = (event.current / event.total * 100).round();
      final bar = _generateProgressBar(event.current, event.total);
      final url = event.url != null ? ' (${event.url})' : '';
      _console.write('\r$bar $percentage% ${event.message}$url');
      if (event.current >= event.total) {
        _console.writeln();
      }
    } else {
      _console.info(event.message);
    }
  }

  void _handleStarted(StartedEvent event) {
    final completer = Completer<TaskResult>();
    _pendingTasks[event.moduleId] = completer;
    unawaited(_console.task(event.message, run: () => completer.future));
  }

  void _handleCompleted(CompletedEvent event) {
    final completer = _pendingTasks.remove(event.moduleId);
    if (completer != null) {
      completer.complete(TaskResult.success);
    } else {
      _console.success(event.message);
    }
  }

  void _handleFailed(FailedEvent event) {
    final completer = _pendingTasks.remove(event.moduleId);
    if (completer != null) {
      completer.complete(TaskResult.failure);
    }
    if (event.errorCode != null) {
      _console.writeln('   Error Code: ${event.errorCode}');
    }
    if (event.cause != null) {
      _console.writeln('   Cause: ${event.cause}');
    }
  }

  void _handleError(ErrorEvent event) {
    _console.error(event.message);
    if (_debugMode) {
      _console.writeln('   Category: ${event.category}');
      _console.writeln('   Error Code: ${event.errorCode}');
      if (event.cause != null) {
        _console.writeln('   Cause: ${event.cause}');
      }
    }
  }

  void _handleResourceStarted(ResourceStartedEvent event) {
    _console.section('Starting ${event.resourceType}');
    _console.writeln('   Source: ${event.source}');
    _console.writeln('   Destination: ${event.destination}');
    _console.writeln('   Actions: ${event.actionCount}');
  }

  void _handleResourceCompleted(ResourceCompletedEvent event) {
    final duration = _formatDuration(event.duration);
    _console.success('Completed ${event.resourceType}');
    _console.info(
      '   Actions: ${event.completedActions}/${event.totalActions}',
    );
    _console.info('   Duration: $duration');
  }

  void _handleResourceRollbackStarted(ResourceRollbackStartedEvent event) {
    _console.writeln('Rolling back ${event.resourceType}');
    _console.writeln('   Source: ${event.source}');
    _console.writeln('   Destination: ${event.destination}');
    _console.writeln('   Actions: ${event.actionCount}');
  }

  void _handleResourceRollbackCompleted(ResourceRollbackCompletedEvent event) {
    final duration = _formatDuration(event.duration);
    _console.success(
      'Rollback completed for ${event.resourceType}',
    );
    _console.info(
      '   Actions: ${event.rolledbackActions}/${event.totalActions}',
    );
    _console.info('   Duration: $duration');
  }

  // ---------------------------------------------------------------------------
  // Utility methods
  // ---------------------------------------------------------------------------

  String _generateProgressBar(int current, int total) {
    const barLength = 20;
    final filled = (current / total * barLength).round();
    final bar = '█' * filled + '░' * (barLength - filled);
    return '[$bar]';
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  // ---------------------------------------------------------------------------
  // UIHandler interface methods
  // ---------------------------------------------------------------------------

  @override
  void handleEvent(ModuleEvent event) {
    // Events are handled by the stream listener
  }

  @override
  void start() {
    // Already started in constructor
  }

  @override
  void stop() {
    // Nothing to stop
  }

  @override
  void enableInteractiveMode() {
    // Already handled in constructor
  }

  @override
  void disableInteractiveMode() {
    // Already handled in constructor
  }

  @override
  void enablePasswordPromptMode() {
    // Not needed for this handler
  }

  @override
  void disablePasswordPromptMode() {
    // Not needed for this handler
  }

  void enableVerboseMode() {
    // Already handled in constructor
  }

  void disableVerboseMode() {
    // Already handled in constructor
  }

  void enableDebugMode() {
    // Already handled in constructor
  }

  void disableDebugMode() {
    // Already handled in constructor
  }

  // Interactive methods that emit events instead of direct input
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
    return defaultValue ?? options.first;
  }

  @override
  String promptPassword(String message) {
    return '';
  }

  @override
  void showMessage(String message) {
    _console.info(message);
  }

  @override
  void showWarning(String message) {
    _console.warn(message);
  }

  @override
  void showError(String message) {
    _console.error(message);
  }

  @override
  void showSuccess(String message) {
    _console.success(message);
  }

  void setEventBus(EventBus eventBus) {
    _eventBus = eventBus;
  }
}
