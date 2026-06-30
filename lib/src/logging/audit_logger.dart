import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/utils/event_bus.dart';

/// Log levels for audit logging
enum AuditLogLevel { trace, debug, info, warning, error, critical }

/// Audit log entry
class AuditLogEntry {
  final String id;
  final AuditLogLevel level;
  final String message;
  final String? moduleId;
  final String? operation;
  final String? userId;
  final String? sessionId;
  final String? correlationId;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;

  AuditLogEntry({
    required this.id,
    required this.level,
    required this.message,
    this.moduleId,
    this.operation,
    this.userId,
    this.sessionId,
    this.correlationId,
    this.metadata,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'level': level.name,
      'message': message,
      'moduleId': moduleId,
      'operation': operation,
      'userId': userId,
      'sessionId': sessionId,
      'correlationId': correlationId,
      'metadata': metadata,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  String toJson() {
    return jsonEncode(toMap());
  }
}

/// Audit log configuration
class AuditLogConfig {
  final bool enabled;
  final AuditLogLevel minLevel;
  final String? logFile;
  final bool includeMetadata;
  final bool includeStackTrace;
  final int maxFileSize;
  final int maxFiles;
  final Duration flushInterval;
  final bool compressOldFiles;

  const AuditLogConfig({
    this.enabled = true,
    this.minLevel = AuditLogLevel.info,
    this.logFile,
    this.includeMetadata = true,
    this.includeStackTrace = false,
    this.maxFileSize = 10 * 1024 * 1024, // 10MB
    this.maxFiles = 5,
    this.flushInterval = const Duration(seconds: 30),
    this.compressOldFiles = true,
  });
}

/// Audit logger for comprehensive logging and audit trails
class AuditLogger {
  static final AuditLogger _instance = AuditLogger._internal();

  factory AuditLogger() => _instance;

  AuditLogger._internal();

  final List<AuditLogEntry> _logBuffer = [];
  final EventBus _eventBus = EventBus();
  final Map<String, String> _context = {};
  AuditLogConfig _config = const AuditLogConfig();
  Timer? _flushTimer;
  IOSink? _logSink;
  int _currentFileSize = 0;
  int _fileCounter = 0;

  /// Get current configuration
  AuditLogConfig get config => _config;

  /// Get current context
  Map<String, String> get context => Map.unmodifiable(_context);

  /// Initialize the audit logger
  Future<void> initialize(AuditLogConfig config) async {
    _config = config;

    if (_config.enabled && _config.logFile != null) {
      await _openLogFile();
      _startFlushTimer();
    }
  }

  /// Set context information
  void setContext(String key, String value) {
    _context[key] = value;
  }

  /// Remove context information
  void removeContext(String key) {
    _context.remove(key);
  }

  /// Clear all context
  void clearContext() {
    _context.clear();
  }

  /// Log a trace message
  void trace(
    String message, {
    String? moduleId,
    String? operation,
    String? userId,
    String? sessionId,
    String? correlationId,
    Map<String, dynamic>? metadata,
  }) {
    _log(
      AuditLogLevel.trace,
      message,
      moduleId: moduleId,
      operation: operation,
      userId: userId,
      sessionId: sessionId,
      correlationId: correlationId,
      metadata: metadata,
    );
  }

  /// Log a debug message
  void debug(
    String message, {
    String? moduleId,
    String? operation,
    String? userId,
    String? sessionId,
    String? correlationId,
    Map<String, dynamic>? metadata,
  }) {
    _log(
      AuditLogLevel.debug,
      message,
      moduleId: moduleId,
      operation: operation,
      userId: userId,
      sessionId: sessionId,
      correlationId: correlationId,
      metadata: metadata,
    );
  }

  /// Log an info message
  void info(
    String message, {
    String? moduleId,
    String? operation,
    String? userId,
    String? sessionId,
    String? correlationId,
    Map<String, dynamic>? metadata,
  }) {
    _log(
      AuditLogLevel.info,
      message,
      moduleId: moduleId,
      operation: operation,
      userId: userId,
      sessionId: sessionId,
      correlationId: correlationId,
      metadata: metadata,
    );
  }

  /// Log a warning message
  void warning(
    String message, {
    String? moduleId,
    String? operation,
    String? userId,
    String? sessionId,
    String? correlationId,
    Map<String, dynamic>? metadata,
  }) {
    _log(
      AuditLogLevel.warning,
      message,
      moduleId: moduleId,
      operation: operation,
      userId: userId,
      sessionId: sessionId,
      correlationId: correlationId,
      metadata: metadata,
    );
  }

  /// Log an error message
  void error(
    String message, {
    String? moduleId,
    String? operation,
    String? userId,
    String? sessionId,
    String? correlationId,
    Map<String, dynamic>? metadata,
    Object? errorObject,
    StackTrace? stackTrace,
  }) {
    final errorMetadata = <String, dynamic>{};
    if (errorObject != null) {
      errorMetadata['error'] = errorObject.toString();
    }
    if (stackTrace != null && _config.includeStackTrace) {
      errorMetadata['stackTrace'] = stackTrace.toString();
    }
    if (metadata != null) {
      errorMetadata.addAll(metadata);
    }

    _log(
      AuditLogLevel.error,
      message,
      moduleId: moduleId,
      operation: operation,
      userId: userId,
      sessionId: sessionId,
      correlationId: correlationId,
      metadata: errorMetadata.isNotEmpty ? errorMetadata : null,
    );
  }

  /// Log a critical message
  void critical(
    String message, {
    String? moduleId,
    String? operation,
    String? userId,
    String? sessionId,
    String? correlationId,
    Map<String, dynamic>? metadata,
    Object? errorObject,
    StackTrace? stackTrace,
  }) {
    final errorMetadata = <String, dynamic>{};
    if (errorObject != null) {
      errorMetadata['error'] = errorObject.toString();
    }
    if (stackTrace != null && _config.includeStackTrace) {
      errorMetadata['stackTrace'] = stackTrace.toString();
    }
    if (metadata != null) {
      errorMetadata.addAll(metadata);
    }

    _log(
      AuditLogLevel.critical,
      message,
      moduleId: moduleId,
      operation: operation,
      userId: userId,
      sessionId: sessionId,
      correlationId: correlationId,
      metadata: errorMetadata.isNotEmpty ? errorMetadata : null,
    );
  }

  /// Log operation start
  void logOperationStart(
    String operation, {
    String? moduleId,
    String? userId,
    String? sessionId,
    String? correlationId,
    Map<String, dynamic>? metadata,
  }) {
    info(
      'Operation started: $operation',
      moduleId: moduleId,
      operation: operation,
      userId: userId,
      sessionId: sessionId,
      correlationId: correlationId,
      metadata: metadata,
    );
  }

  /// Log operation completion
  void logOperationComplete(
    String operation, {
    String? moduleId,
    String? userId,
    String? sessionId,
    String? correlationId,
    Duration? duration,
    Map<String, dynamic>? metadata,
  }) {
    final completeMetadata = <String, dynamic>{};
    if (duration != null) {
      completeMetadata['duration'] = duration.inMilliseconds;
    }
    if (metadata != null) {
      completeMetadata.addAll(metadata);
    }

    info(
      'Operation completed: $operation',
      moduleId: moduleId,
      operation: operation,
      userId: userId,
      sessionId: sessionId,
      correlationId: correlationId,
      metadata: completeMetadata.isNotEmpty ? completeMetadata : null,
    );
  }

  /// Log operation failure
  void logOperationFailure(
    String operation, {
    String? moduleId,
    String? userId,
    String? sessionId,
    String? correlationId,
    String? reason,
    Object? errorObject,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    final failureMetadata = <String, dynamic>{};
    if (reason != null) {
      failureMetadata['reason'] = reason;
    }
    if (metadata != null) {
      failureMetadata.addAll(metadata);
    }

    error(
      'Operation failed: $operation',
      moduleId: moduleId,
      operation: operation,
      userId: userId,
      sessionId: sessionId,
      correlationId: correlationId,
      metadata: failureMetadata.isNotEmpty ? failureMetadata : null,
      errorObject: errorObject,
      stackTrace: stackTrace,
    );
  }

  /// Log security event
  void logSecurityEvent(
    String event, {
    String? moduleId,
    String? operation,
    String? userId,
    String? sessionId,
    String? correlationId,
    String? severity,
    Map<String, dynamic>? metadata,
  }) {
    final securityMetadata = <String, dynamic>{
      'eventType': 'security',
      'severity': severity ?? 'info',
    };
    if (metadata != null) {
      securityMetadata.addAll(metadata);
    }

    warning(
      'Security event: $event',
      moduleId: moduleId,
      operation: operation,
      userId: userId,
      sessionId: sessionId,
      correlationId: correlationId,
      metadata: securityMetadata,
    );
  }

  /// Get recent log entries
  List<AuditLogEntry> getRecentEntries({int limit = 100}) {
    final start = _logBuffer.length - limit;
    final end = start < 0 ? 0 : start;
    return _logBuffer.sublist(end);
  }

  /// Get log entries by level
  List<AuditLogEntry> getEntriesByLevel(AuditLogLevel level) {
    return _logBuffer.where((entry) => entry.level == level).toList();
  }

  /// Get log entries by module
  List<AuditLogEntry> getEntriesByModule(String moduleId) {
    return _logBuffer.where((entry) => entry.moduleId == moduleId).toList();
  }

  /// Get log entries by operation
  List<AuditLogEntry> getEntriesByOperation(String operation) {
    return _logBuffer.where((entry) => entry.operation == operation).toList();
  }

  /// Get log entries by user
  List<AuditLogEntry> getEntriesByUser(String userId) {
    return _logBuffer.where((entry) => entry.userId == userId).toList();
  }

  /// Get log statistics
  Map<String, dynamic> getStatistics() {
    final total = _logBuffer.length;
    final byLevel = <String, int>{};
    final byModule = <String, int>{};
    final byOperation = <String, int>{};

    for (final entry in _logBuffer) {
      byLevel[entry.level.name] = (byLevel[entry.level.name] ?? 0) + 1;
      if (entry.moduleId != null) {
        byModule[entry.moduleId!] = (byModule[entry.moduleId!] ?? 0) + 1;
      }
      if (entry.operation != null) {
        byOperation[entry.operation!] =
            (byOperation[entry.operation!] ?? 0) + 1;
      }
    }

    return {
      'total': total,
      'byLevel': byLevel,
      'byModule': byModule,
      'byOperation': byOperation,
      'bufferSize': _logBuffer.length,
      'config': {
        'enabled': _config.enabled,
        'minLevel': _config.minLevel.name,
        'logFile': _config.logFile,
      },
    };
  }

  /// Flush logs to file
  Future<void> flush() async {
    if (_logSink == null || _logBuffer.isEmpty) return;

    try {
      for (final entry in _logBuffer) {
        _logSink!.writeln(entry.toJson());
        _currentFileSize += entry.toJson().length + 1; // +1 for newline
      }
      await _logSink!.flush();
      _logBuffer.clear();

      // Rotate file if needed
      if (_currentFileSize >= _config.maxFileSize) {
        await _rotateLogFile();
      }
    } catch (e) {
      // Log error but don't throw
      print('Failed to flush audit log: $e');
    }
  }

  /// Close the audit logger
  Future<void> close() async {
    _flushTimer?.cancel();
    await flush();
    await _logSink?.close();
    _logSink = null;
  }

  /// Internal log method
  void _log(
    AuditLogLevel level,
    String message, {
    String? moduleId,
    String? operation,
    String? userId,
    String? sessionId,
    String? correlationId,
    Map<String, dynamic>? metadata,
  }) {
    if (!_config.enabled || level.index < _config.minLevel.index) {
      return;
    }

    final entry = AuditLogEntry(
      id: _generateId(),
      level: level,
      message: message,
      moduleId: moduleId,
      operation: operation,
      userId: userId,
      sessionId: sessionId,
      correlationId: correlationId,
      metadata: _config.includeMetadata ? _mergeMetadata(metadata) : metadata,
    );

    _logBuffer.add(entry);

    // Emit event for real-time monitoring
    _eventBus.emit(
      StatusUpdateEvent(
        level: _getStatusLevel(level),
        message: message,
        moduleId: moduleId ?? 'AuditLogger',
        metadata: entry.toMap(),
      ),
    );

    // Auto-flush if buffer is too large
    if (_logBuffer.length >= 1000) {
      // Don't await to avoid blocking the log call
      flush().catchError((e) => print('Auto-flush failed: $e'));
    }
  }

  /// Open log file
  Future<void> _openLogFile() async {
    if (_config.logFile == null) return;

    try {
      final file = File(_config.logFile!);
      await file.create(recursive: true);
      _logSink = file.openWrite(mode: FileMode.append);
      _currentFileSize = await file.length();
    } catch (e) {
      print('Failed to open audit log file: $e');
    }
  }

  /// Rotate log file
  Future<void> _rotateLogFile() async {
    if (_config.logFile == null) return;

    try {
      await _logSink?.close();
      _fileCounter++;

      final file = File(_config.logFile!);
      final rotatedFile = File('${_config.logFile}.$_fileCounter');

      if (await file.exists()) {
        await file.rename(rotatedFile.path);

        if (_config.compressOldFiles) {
          // TODO: Implement compression
        }
      }

      // Clean up old files
      await _cleanupOldFiles();

      // Open new file
      await _openLogFile();
    } catch (e) {
      print('Failed to rotate audit log file: $e');
    }
  }

  /// Clean up old log files
  Future<void> _cleanupOldFiles() async {
    if (_config.logFile == null) return;

    try {
      final file = File(_config.logFile!);
      final directory = file.parent;
      final baseName = file.uri.pathSegments.last;

      final files = directory
          .listSync()
          .where((f) => f is File && f.path.contains(baseName))
          .cast<File>()
          .toList();

      files.sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
      );

      // Keep only maxFiles
      for (int i = _config.maxFiles; i < files.length; i++) {
        await files[i].delete();
      }
    } catch (e) {
      print('Failed to cleanup old log files: $e');
    }
  }

  /// Start flush timer
  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_config.flushInterval, (_) {
      flush();
    });
  }

  /// Generate unique ID
  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_logBuffer.length}';
  }

  /// Merge context with metadata
  Map<String, dynamic>? _mergeMetadata(Map<String, dynamic>? metadata) {
    if (_context.isEmpty && metadata == null) return null;

    final merged = <String, dynamic>{};
    merged.addAll(_context);
    if (metadata != null) {
      merged.addAll(metadata);
    }
    return merged;
  }

  /// Convert audit log level to status event level
  StatusEvent _getStatusLevel(AuditLogLevel level) {
    switch (level) {
      case AuditLogLevel.trace:
      case AuditLogLevel.debug:
        return StatusEvent.debug;
      case AuditLogLevel.info:
        return StatusEvent.info;
      case AuditLogLevel.warning:
        return StatusEvent.warning;
      case AuditLogLevel.error:
      case AuditLogLevel.critical:
        return StatusEvent.error;
    }
  }
}
