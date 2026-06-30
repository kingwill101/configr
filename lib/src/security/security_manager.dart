import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/utils/event_bus.dart';

/// Security level for operations
enum SecurityLevel { low, medium, high, critical }

/// Security policy definition
class SecurityPolicy {
  final String name;
  final SecurityLevel level;
  final Map<String, dynamic> rules;
  final List<String> allowedOperations;
  final List<String> deniedOperations;
  final Map<String, dynamic>? metadata;

  const SecurityPolicy({
    required this.name,
    required this.level,
    this.rules = const {},
    this.allowedOperations = const [],
    this.deniedOperations = const [],
    this.metadata,
  });

  factory SecurityPolicy.fromMap(Map<String, dynamic> map) {
    return SecurityPolicy(
      name: map['name'] as String,
      level: SecurityLevel.values.firstWhere(
        (e) => e.name == map['level'],
        orElse: () => SecurityLevel.medium,
      ),
      rules: Map<String, dynamic>.from(map['rules'] ?? {}),
      allowedOperations: List<String>.from(map['allowedOperations'] ?? []),
      deniedOperations: List<String>.from(map['deniedOperations'] ?? []),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'level': level.name,
      'rules': rules,
      'allowedOperations': allowedOperations,
      'deniedOperations': deniedOperations,
      'metadata': metadata,
    };
  }
}

/// Security context for operations
class SecurityContext {
  final String? userId;
  final String? sessionId;
  final String? ipAddress;
  final Map<String, dynamic>? attributes;
  final DateTime timestamp;

  SecurityContext({
    this.userId,
    this.sessionId,
    this.ipAddress,
    this.attributes,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'sessionId': sessionId,
      'ipAddress': ipAddress,
      'attributes': attributes,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Security audit event
class SecurityAuditEvent {
  final String eventType;
  final String operation;
  final SecurityContext context;
  final bool success;
  final String? reason;
  final Map<String, dynamic>? details;
  final DateTime timestamp;

  SecurityAuditEvent({
    required this.eventType,
    required this.operation,
    required this.context,
    required this.success,
    this.reason,
    this.details,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'eventType': eventType,
      'operation': operation,
      'context': context.toMap(),
      'success': success,
      'reason': reason,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Security manager for handling security policies and validation
class SecurityManager {
  static final SecurityManager _instance = SecurityManager._internal();

  factory SecurityManager() => _instance;

  SecurityManager._internal();

  final Map<String, SecurityPolicy> _policies = {};
  final List<SecurityAuditEvent> _auditLog = [];
  final EventBus _eventBus = EventBus();
  final Map<String, List<String>> _blacklistedPaths = {};
  final Map<String, List<String>> _whitelistedPaths = {};
  bool _enabled = true;
  int _maxAuditLogSize = 10000;

  /// Check if security is enabled
  bool get isEnabled => _enabled;

  /// Enable security
  void enable() {
    _enabled = true;
  }

  /// Disable security
  void disable() {
    _enabled = false;
  }

  /// Register a security policy
  void registerPolicy(SecurityPolicy policy) {
    _policies[policy.name] = policy;
  }

  /// Unregister a security policy
  void unregisterPolicy(String name) {
    _policies.remove(name);
  }

  /// Get a security policy
  SecurityPolicy? getPolicy(String name) {
    return _policies[name];
  }

  /// Get all policies
  Map<String, SecurityPolicy> get policies => Map.unmodifiable(_policies);

  /// Check if operation is allowed
  bool isOperationAllowed(String operation, SecurityContext context) {
    if (!_enabled) return true;

    // Check blacklisted operations
    for (final policy in _policies.values) {
      if (policy.deniedOperations.contains(operation)) {
        _auditEvent(
          'operation_denied',
          operation,
          context,
          false,
          'Operation denied by policy: ${policy.name}',
        );
        return false;
      }
    }

    // Check whitelisted operations
    for (final policy in _policies.values) {
      if (policy.allowedOperations.isNotEmpty &&
          !policy.allowedOperations.contains(operation)) {
        _auditEvent(
          'operation_denied',
          operation,
          context,
          false,
          'Operation not in allowed list for policy: ${policy.name}',
        );
        return false;
      }
    }

    _auditEvent('operation_allowed', operation, context, true);
    return true;
  }

  /// Validate file path access
  bool isPathAllowed(String path, SecurityContext context) {
    if (!_enabled) return true;

    // Check blacklisted paths
    for (final entry in _blacklistedPaths.entries) {
      final pattern = entry.key;
      final users = entry.value;

      if (_matchesPattern(path, pattern) &&
          (users.isEmpty || users.contains(context.userId ?? ''))) {
        _auditEvent(
          'path_access_denied',
          'file_access',
          context,
          false,
          'Path blacklisted: $path',
        );
        return false;
      }
    }

    // Check whitelisted paths (if any exist)
    if (_whitelistedPaths.isNotEmpty) {
      bool allowed = false;
      for (final entry in _whitelistedPaths.entries) {
        final pattern = entry.key;
        final users = entry.value;

        if (_matchesPattern(path, pattern) &&
            (users.isEmpty || users.contains(context.userId ?? ''))) {
          allowed = true;
          break;
        }
      }

      if (!allowed) {
        _auditEvent(
          'path_access_denied',
          'file_access',
          context,
          false,
          'Path not whitelisted: $path',
        );
        return false;
      }
    }

    _auditEvent(
      'path_access_allowed',
      'file_access',
      context,
      true,
      'Path access allowed',
      {'path': path},
    );
    return true;
  }

  /// Validate input data
  bool validateInput(String operation, dynamic input, SecurityContext context) {
    if (!_enabled) return true;

    try {
      // Check for potential security issues
      if (input is String) {
        if (_containsMaliciousContent(input)) {
          _auditEvent(
            'input_validation_failed',
            operation,
            context,
            false,
            'Malicious content detected',
          );
          return false;
        }
      } else if (input is Map) {
        for (final value in input.values) {
          if (!validateInput(operation, value, context)) {
            return false;
          }
        }
      } else if (input is List) {
        for (final item in input) {
          if (!validateInput(operation, item, context)) {
            return false;
          }
        }
      }

      _auditEvent('input_validation_passed', operation, context, true);
      return true;
    } catch (e) {
      _auditEvent(
        'input_validation_error',
        operation,
        context,
        false,
        'Validation error: ${e.toString()}',
      );
      return false;
    }
  }

  /// Add blacklisted path pattern
  void addBlacklistedPath(String pattern, {List<String>? users}) {
    _blacklistedPaths[pattern] = users ?? [];
  }

  /// Add whitelisted path pattern
  void addWhitelistedPath(String pattern, {List<String>? users}) {
    _whitelistedPaths[pattern] = users ?? [];
  }

  /// Remove blacklisted path pattern
  void removeBlacklistedPath(String pattern) {
    _blacklistedPaths.remove(pattern);
  }

  /// Remove whitelisted path pattern
  void removeWhitelistedPath(String pattern) {
    _whitelistedPaths.remove(pattern);
  }

  /// Get audit log
  List<SecurityAuditEvent> getAuditLog() {
    return List.unmodifiable(_auditLog);
  }

  /// Get recent audit events
  List<SecurityAuditEvent> getRecentAuditEvents({int limit = 100}) {
    final start = _auditLog.length - limit;
    final end = start < 0 ? 0 : start;
    return _auditLog.sublist(end);
  }

  /// Clear audit log
  void clearAuditLog() {
    _auditLog.clear();
  }

  /// Set maximum audit log size
  void setMaxAuditLogSize(int size) {
    _maxAuditLogSize = size;
    _trimAuditLog();
  }

  /// Get security statistics
  Map<String, dynamic> getSecurityStats() {
    final recent = getRecentAuditEvents(limit: 1000);
    final allowed = recent.where((e) => e.success).length;
    final denied = recent.where((e) => !e.success).length;

    final eventTypes = <String, int>{};
    for (final event in recent) {
      eventTypes[event.eventType] = (eventTypes[event.eventType] ?? 0) + 1;
    }

    return {
      'enabled': _enabled,
      'policies': _policies.length,
      'blacklistedPaths': _blacklistedPaths.length,
      'whitelistedPaths': _whitelistedPaths.length,
      'auditLogSize': _auditLog.length,
      'recentEvents': {
        'total': recent.length,
        'allowed': allowed,
        'denied': denied,
        'eventTypes': eventTypes,
      },
    };
  }

  /// Check if content contains malicious patterns
  bool _containsMaliciousContent(String content) {
    final maliciousPatterns = [
      r'<script[^>]*>.*?</script>', // Script tags
      r'javascript:', // JavaScript URLs
      r'data:text/html', // Data URLs
      r'vbscript:', // VBScript URLs
      r'on\w+\s*=', // Event handlers
      r'expression\s*\(', // CSS expressions
      r'url\s*\(', // CSS URLs
      r'@import', // CSS imports
      r'\.\./', // Path traversal
      r'\.\.\\', // Path traversal (Windows)
      r'%2e%2e%2f', // URL encoded path traversal
      r'%2e%2e%5c', // URL encoded path traversal (Windows)
    ];

    for (final pattern in maliciousPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(content)) {
        return true;
      }
    }

    return false;
  }

  /// Check if path matches pattern
  bool _matchesPattern(String path, String pattern) {
    // Simple pattern matching - in a real implementation, this would be more sophisticated
    if (pattern.contains('*')) {
      final regexPattern = pattern.replaceAll('*', '.*');
      return RegExp('^$regexPattern\$').hasMatch(path);
    }
    return path == pattern;
  }

  /// Emit a security event directly (used by external components).
  void audit(SecurityEvent event) {
    _auditLog.add(
      SecurityAuditEvent(
        eventType: event.securityEventType,
        operation: event.resource ?? 'unknown',
        context: SecurityContext(userId: event.userId),
        success: event.severity != 'critical',
        reason: event.details?.toString(),
        details: event.details,
      ),
    );
    _trimAuditLog();
    _eventBus.emit(event);
  }

  /// Record audit event
  void _auditEvent(
    String eventType,
    String operation,
    SecurityContext context,
    bool success, [
    String? reason,
    Map<String, dynamic>? details,
  ]) {
    final event = SecurityAuditEvent(
      eventType: eventType,
      operation: operation,
      context: context,
      success: success,
      reason: reason,
      details: details,
    );

    _auditLog.add(event);
    _trimAuditLog();

    // Emit security event
    _eventBus.emit(
      SecurityEvent(
        securityEventType: eventType,
        severity: success ? 'info' : 'warning',
        userId: context.userId,
        resource: operation,
        details: {'success': success, 'reason': reason, 'details': details},
        moduleId: 'SecurityManager',
      ),
    );
  }

  /// Trim audit log to maximum size
  void _trimAuditLog() {
    while (_auditLog.length > _maxAuditLogSize) {
      _auditLog.removeAt(0);
    }
  }

  /// Clear all security data
  void clear() {
    _policies.clear();
    _auditLog.clear();
    _blacklistedPaths.clear();
    _whitelistedPaths.clear();
  }
}
