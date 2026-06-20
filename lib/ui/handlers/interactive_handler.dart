import 'dart:io';

import 'package:configr/events/module_events.dart';
import 'package:configr/ui/handlers/base_handler.dart';
import 'package:configr/utils/event_bus.dart';

/// Interactive UI handler that properly handles user input with event coordination
class InteractiveHandler implements UIHandler {
  EventBus _eventBus;
  final bool _verboseMode;
  final bool _debugMode;
  final bool _interactiveMode;
  
  
  InteractiveHandler({
    required EventBus eventBus,
    bool verboseMode = false,
    bool debugMode = false,
    bool interactiveMode = true,
  }) : _eventBus = eventBus,
       _verboseMode = verboseMode,
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
      final input = event.defaultValue ?? 
                   (event.options?.isNotEmpty == true ? event.options!.first : '');
      _eventBus.emit(UserInputReceivedEvent(
        moduleId: event.moduleId,
        correlationId: event.correlationId,
        input: input,
        inputType: event.inputType,
      ));
      return;
    }

    // In interactive mode, prompt for input
    _promptForInput(event);
  }

  void _handleWaitForUser(WaitForUserEvent event) {
    if (_interactiveMode) {
      print('\n⏸️  Waiting for user input: ${event.reason}');
      print('Press Enter to continue...');
      stdin.readLineSync();
      _eventBus.emit(ResumeProcessingEvent(
        moduleId: event.moduleId,
        correlationId: event.correlationId,
      ));
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
      print('🔍 [DEBUG] ${event.runtimeType}: ${event.toStructuredData()}');
    }
  }

  void _promptForInput(UserInputRequiredEvent event) {
    final correlationId = event.correlationId ?? DateTime.now().millisecondsSinceEpoch.toString();
    
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
    final promptText = event.defaultValue != null 
        ? '${event.prompt} [${event.defaultValue}]: '
        : '${event.prompt}: ';
    
    stdout.write(promptText);
    final input = stdin.readLineSync()?.trim() ?? '';
    final result = input.isEmpty ? (event.defaultValue ?? '') : input;
    
    _eventBus.emit(UserInputReceivedEvent(
      moduleId: event.moduleId,
      correlationId: correlationId,
      input: result,
      inputType: event.inputType,
    ));
  }

  void _promptPassword(UserInputRequiredEvent event, String correlationId) {
    stdout.write('${event.prompt}: ');
    stdin.echoMode = false;
    final password = stdin.readLineSync() ?? '';
    stdin.echoMode = true;
    print(''); // Add newline after hidden input
    
    _eventBus.emit(UserInputReceivedEvent(
      moduleId: event.moduleId,
      correlationId: correlationId,
      input: password,
      inputType: event.inputType,
    ));
  }

  void _promptConfirm(UserInputRequiredEvent event, String correlationId) {
    final defaultText = event.defaultValue == 'true' ? 'Y/n' : 'y/N';
    final promptText = '${event.prompt} [$defaultText]: ';
    
    stdout.write(promptText);
    final input = stdin.readLineSync()?.trim().toLowerCase() ?? '';
    final result = input.isEmpty 
        ? (event.defaultValue == 'true' ? 'true' : 'false')
        : (input.startsWith('y') ? 'true' : 'false');
    
    _eventBus.emit(UserInputReceivedEvent(
      moduleId: event.moduleId,
      correlationId: correlationId,
      input: result,
      inputType: event.inputType,
    ));
  }

  void _promptSelect(UserInputRequiredEvent event, String correlationId) {
    print('\n${event.prompt}');
    if (event.options != null) {
      for (int i = 0; i < event.options!.length; i++) {
        final marker = event.defaultValue == event.options![i] ? ' (default)' : '';
        print('  ${i + 1}. ${event.options![i]}$marker');
      }
    }
    
    stdout.write('Select option [1-${event.options?.length ?? 1}]: ');
    final input = stdin.readLineSync()?.trim() ?? '';
    
    String result;
    if (input.isEmpty && event.defaultValue != null) {
      result = event.defaultValue!;
    } else {
      final index = int.tryParse(input);
      if (index != null && index >= 1 && index <= (event.options?.length ?? 1)) {
        result = event.options?[index - 1] ?? event.defaultValue ?? '';
      } else {
        result = event.defaultValue ?? (event.options?.first ?? '');
      }
    }
    
    _eventBus.emit(UserInputReceivedEvent(
      moduleId: event.moduleId,
      correlationId: correlationId,
      input: result,
      inputType: event.inputType,
    ));
  }

  // Event handling methods
  void _handleStatusUpdate(StatusUpdateEvent event) {
    final prefix = _getStatusPrefix(event.level);
    final message = _formatMessage(event.message);
    print('$prefix $message');
  }

  void _handleProgress(ProgressEvent event) {
    if (event.total > 0) {
      final percentage = (event.current / event.total * 100).round();
      final bar = _generateProgressBar(event.current, event.total);
      print('\r🔄 $bar $percentage% ${event.message}');
      if (event.current >= event.total) {
        print(''); // New line when complete
      }
    } else {
      print('🔄 ${event.message}');
    }
  }

  void _handleDownloadProgress(DownloadProgressEvent event) {
    if (event.total > 0) {
      final percentage = (event.current / event.total * 100).round();
      final bar = _generateProgressBar(event.current, event.total);
      final url = event.url != null ? ' (${event.url})' : '';
      print('\r⬇️  $bar $percentage% ${event.message}$url');
      if (event.current >= event.total) {
        print(''); // New line when complete
      }
    } else {
      print('⬇️  ${event.message}');
    }
  }

  void _handleStarted(StartedEvent event) {
    print('🔄 ${event.message}');
  }

  void _handleCompleted(CompletedEvent event) {
    final duration = event.duration != null 
        ? ' (${_formatDuration(event.duration!)})'
        : '';
    print('✅ ${event.message}$duration');
  }

  void _handleFailed(FailedEvent event) {
    print('❌ ${event.message}');
    if (event.errorCode != null) {
      print('   Error Code: ${event.errorCode}');
    }
    if (event.cause != null) {
      print('   Cause: ${event.cause}');
    }
  }

  void _handleError(ErrorEvent event) {
    final severity = _getSeverityPrefix(event.severity);
    print('$severity ${event.message}');
    if (_debugMode) {
      print('   Category: ${event.category}');
      print('   Error Code: ${event.errorCode}');
      if (event.cause != null) {
        print('   Cause: ${event.cause}');
      }
    }
  }

  void _handleResourceStarted(ResourceStartedEvent event) {
    print('🔄 [${event.resourceId}] Starting ${event.resourceType}');
    print('   Source: ${event.source}');
    print('   Destination: ${event.destination}');
    print('   Actions: ${event.actionCount}');
  }

  void _handleResourceCompleted(ResourceCompletedEvent event) {
    final duration = _formatDuration(event.duration);
    print('✅ [${event.resourceId}] Completed ${event.resourceType}');
    print('   Actions: ${event.completedActions}/${event.totalActions}');
    print('   Duration: $duration');
  }

  void _handleResourceRollbackStarted(ResourceRollbackStartedEvent event) {
    print('🔄 [${event.resourceId}] Rolling back ${event.resourceType}');
    print('   Source: ${event.source}');
    print('   Destination: ${event.destination}');
    print('   Actions: ${event.actionCount}');
  }

  void _handleResourceRollbackCompleted(ResourceRollbackCompletedEvent event) {
    final duration = _formatDuration(event.duration);
    print('✅ [${event.resourceId}] Rollback completed for ${event.resourceType}');
    print('   Actions: ${event.rolledbackActions}/${event.totalActions}');
    print('   Duration: $duration');
  }

  // Utility methods
  String _getStatusPrefix(StatusEvent level) {
    switch (level) {
      case StatusEvent.info:
        return 'ℹ️ ';
      case StatusEvent.warning:
        return '⚠️ ';
      case StatusEvent.error:
        return '❌';
      case StatusEvent.debug:
        return '🔍';
    }
  }

  String _getSeverityPrefix(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return '🚨';
      case 'high':
        return '❌';
      case 'medium':
        return '⚠️ ';
      case 'low':
        return 'ℹ️ ';
      default:
        return '❓';
    }
  }

  String _formatMessage(String message) {
    if (_verboseMode) {
      final timestamp = DateTime.now().toIso8601String();
      return '[$timestamp] $message';
    }
    return message;
  }

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

  // BaseHandler implementation
  void handleEvent(ModuleEvent event) {
    // Events are handled by the stream listener
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

  void enablePasswordPromptMode() {
    // Not needed for this handler
  }

  void disablePasswordPromptMode() {
    // Not needed for this handler
  }

  // Interactive methods that emit events instead of direct input
  String prompt(String message, {String? defaultValue}) {
    // Always return default value to prevent infinite loops
    return defaultValue ?? '';
  }

  bool confirm(String message, {bool defaultValue = false}) {
    // Always return default value to prevent infinite loops
    return defaultValue;
  }

  T select<T>(String message, List<T> options, {T? defaultValue}) {
    // Always return default value to prevent infinite loops
    return defaultValue ?? options.first;
  }

  String promptPassword(String message) {
    // Always return empty string to prevent infinite loops
    return '';
  }

  void showMessage(String message) {
    print('ℹ️  $message');
  }

  void showWarning(String message) {
    print('⚠️  $message');
  }

  void showError(String message) {
    print('❌ $message');
  }

  void showSuccess(String message) {
    print('✅ $message');
  }

  // UIHandler interface methods
  void start() {
    // Already started in constructor
  }

  void stop() {
    // Nothing to stop
  }

  void enableInteractiveMode() {
    // Already handled in constructor
  }

  void disableInteractiveMode() {
    // Already handled in constructor
  }

  void setEventBus(EventBus eventBus) {
    _eventBus = eventBus;
  }
}
