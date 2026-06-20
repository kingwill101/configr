import 'dart:io';
import 'package:configr/events/module_events.dart';
import 'package:configr/ui/handlers/base_handler.dart';

/// Simple text-focused CLI handler without fancy terminal features
class CLIHandler implements UIHandler {
  bool _isActive = false;
  bool _interactiveMode = false;
  bool _passwordPromptMode = false;
  bool _verboseMode = false;
  bool _debugMode = false;

  @override
  void start() {
    _isActive = true;
  }

  @override
  void stop() {
    _isActive = false;
  }

  /// Enable interactive input mode
  @override
  void enableInteractiveMode() {
    _interactiveMode = true;
  }

  /// Disable interactive input mode
  @override
  void disableInteractiveMode() {
    _interactiveMode = false;
  }

  /// Enable password prompt mode
  @override
  void enablePasswordPromptMode() {
    _passwordPromptMode = true;
  }

  /// Disable password prompt mode
  @override
  void disablePasswordPromptMode() {
    _passwordPromptMode = false;
  }

  /// Enable verbose mode
  void enableVerboseMode() {
    _verboseMode = true;
  }

  /// Disable verbose mode
  void disableVerboseMode() {
    _verboseMode = false;
  }

  /// Enable debug mode
  void enableDebugMode() {
    _debugMode = true;
  }

  /// Disable debug mode
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
        final debugInfo = _formatEventWithDebug(event);
        print('🔄 [${event.moduleId}] ${startedEvent.message}$debugInfo');
        break;
      case ModuleEventType.progress:
        final progressEvent = event as ProgressEvent;
        if (progressEvent.total > 10) {
          // Use enhanced progress bar for operations with many items
          showProgressWithETA(
            progressEvent.current, 
            progressEvent.total, 
            '${event.moduleId}: ${progressEvent.message}',
          );
        } else {
          // Use simple progress bar for small operations
          final percentage = ((progressEvent.current / progressEvent.total) * 100).round();
          final bar = _generateProgressBar(percentage);
          print('📊 [${event.moduleId}] $bar $percentage% - ${progressEvent.message}');
        }
        break;
      case ModuleEventType.completed:
        final completedEvent = event as CompletedEvent;
        print('✅ [${event.moduleId}] ${completedEvent.message}');
        break;
      case ModuleEventType.failed:
        final failedEvent = event as FailedEvent;
        print('❌ [${event.moduleId}] ${failedEvent.message}');
        break;
      case ModuleEventType.statusUpdate:
        final statusEvent = event as StatusUpdateEvent;
        final icon = statusEvent.level == StatusEvent.warning ? '⚠️' : 'ℹ️';
        print('$icon [${event.moduleId}] ${statusEvent.message}');
        break;
      case ModuleEventType.downloadProgress:
        final downloadEvent = event as DownloadProgressEvent;
        if (downloadEvent.total > 1024 * 1024) { // Use enhanced progress for files > 1MB
          showProgressWithETA(
            downloadEvent.current, 
            downloadEvent.total, 
            '${event.moduleId}: ${downloadEvent.message}',
          );
        } else {
          final percentage = ((downloadEvent.current / downloadEvent.total) * 100).round();
          final bar = _generateProgressBar(percentage);
          print('⬇️ [${event.moduleId}] $bar $percentage% - ${downloadEvent.message}');
        }
        break;
      case ModuleEventType.error:
        final errorEvent = event as ErrorEvent;
        print('💥 [${event.moduleId}] ${errorEvent.message}');
        break;
      case ModuleEventType.retry:
        final retryEvent = event as RetryEvent;
        print('🔄 [${event.moduleId}] Retrying ${retryEvent.operation} (${retryEvent.attempt}/${retryEvent.maxAttempts})');
        break;
      case ModuleEventType.performance:
        final perfEvent = event as PerformanceEvent;
        print('⚡ [${event.moduleId}] ${perfEvent.operation} took ${perfEvent.duration.inMilliseconds}ms');
        break;
      case ModuleEventType.security:
        final securityEvent = event as SecurityEvent;
        print('🔒 [${event.moduleId}] ${securityEvent.securityEventType} (${securityEvent.severity})');
        break;
      case ModuleEventType.plugin:
        final pluginEvent = event as PluginEvent;
        print('🔌 [${event.moduleId}] ${pluginEvent.pluginName} ${pluginEvent.action}');
        break;
      case ModuleEventType.resourceStarted:
        final resourceEvent = event as ResourceStartedEvent;
        print('📦 Starting resource: ${resourceEvent.resourceId}');
        print('   📍 Source: ${resourceEvent.source} → ${resourceEvent.destination}');
        print('   🔧 Actions: ${resourceEvent.actionCount}');
        break;
      case ModuleEventType.resourceCompleted:
        final resourceEvent = event as ResourceCompletedEvent;
        final duration = resourceEvent.duration.inMilliseconds;
        print('✅ Resource completed: ${resourceEvent.resourceId}');
        print('   ⏱️  Duration: ${duration}ms');
        print('   📊 Actions: ${resourceEvent.completedActions}/${resourceEvent.totalActions}');
        print(''); // Add newline between parent resources
        break;
      case ModuleEventType.resourceRollbackStarted:
        final resourceEvent = event as ResourceRollbackStartedEvent;
        print('🔄 Rolling back resource: ${resourceEvent.resourceId}');
        print('   📍 Source: ${resourceEvent.source} → ${resourceEvent.destination}');
        print('   🔧 Actions: ${resourceEvent.actionCount}');
        break;
      case ModuleEventType.resourceRollbackCompleted:
        final resourceEvent = event as ResourceRollbackCompletedEvent;
        final duration = resourceEvent.duration.inMilliseconds;
        print('✅ Resource rollback completed: ${resourceEvent.resourceId}');
        print('   ⏱️  Duration: ${duration}ms');
        print('   📊 Actions: ${resourceEvent.rolledbackActions}/${resourceEvent.totalActions}');
        print(''); // Add newline between parent resources
        break;
      default:
        print('❓ [${event.moduleId}] ${event.eventType.name}: ${event.toString()}');
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
  void showProgressWithETA(int current, int total, String message) {
    if (!_isActive) return;
    
    final progressBar = _generateEnhancedProgressBar(current, total, message);
    
    // Use carriage return to overwrite the same line
    stdout.write('\r📊 $progressBar');
    if (current >= total) {
      stdout.write('\n'); // New line when complete
    }
  }


  /// Determine if an event should be shown based on verbose/debug modes
  bool _shouldShowEvent(ModuleEvent event) {
    switch (event.eventType) {
      case ModuleEventType.started:
      case ModuleEventType.completed:
      case ModuleEventType.failed:
      case ModuleEventType.error:
        // Always show critical events
        return true;
      
      case ModuleEventType.progress:
      case ModuleEventType.downloadProgress:
        // Show progress in verbose mode or for important operations
        return _verboseMode || _debugMode;
      
      case ModuleEventType.statusUpdate:
        // Show status updates in verbose mode
        return _verboseMode || _debugMode;
      
      case ModuleEventType.retry:
        // Show retry attempts in verbose mode
        return _verboseMode || _debugMode;
      
      case ModuleEventType.performance:
        // Show performance metrics in debug mode
        return _debugMode;
      
      case ModuleEventType.security:
        // Always show security events
        return true;
      
      case ModuleEventType.plugin:
        // Show plugin events in verbose mode
        return _verboseMode || _debugMode;
      
      case ModuleEventType.resourceStarted:
      case ModuleEventType.resourceCompleted:
      case ModuleEventType.resourceRollbackStarted:
      case ModuleEventType.resourceRollbackCompleted:
        // Show resource events in verbose mode
        return _verboseMode || _debugMode;
      
      default:
        // Show unknown events in debug mode
        return _debugMode;
    }
  }

  /// Format event with additional debug information
  String _formatEventWithDebug(ModuleEvent event) {
    if (!_debugMode) return '';
    
    final timestamp = DateTime.now().toIso8601String();
    return ' [$timestamp]';
  }

  /// Prompt user for input with a message
  String prompt(String message, {String? defaultValue}) {
    // Always return default value to avoid interactive issues
    return defaultValue ?? '';
  }

  /// Prompt user for confirmation (yes/no)
  bool confirm(String message, {bool defaultValue = false}) {
    // Always return default value to avoid interactive issues
    return defaultValue;
  }

  /// Prompt user to select from a list of options
  T select<T>(String message, List<T> options, {T? defaultValue}) {
    // Always return default value to avoid interactive issues
    return defaultValue ?? options.first;
  }

  /// Prompt user for password (hidden input)
  String promptPassword(String message) {
    // Always return empty string to avoid interactive issues
    return '';
  }

  /// Show a message in interactive mode
  void showMessage(String message) {
    if (_interactiveMode) {
      print(message);
    }
  }

  /// Show a warning message in interactive mode
  void showWarning(String message) {
    if (_interactiveMode) {
      print('⚠️  $message');
    }
  }

  /// Show an error message in interactive mode
  void showError(String message) {
    if (_interactiveMode) {
      print('❌ $message');
    }
  }

  /// Show a success message in interactive mode
  void showSuccess(String message) {
    if (_interactiveMode) {
      print('✅ $message');
    }
  }
}