import 'dart:async';

import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/event_bus.dart';

/// Health check status
enum HealthStatus {
  healthy,
  degraded,
  unhealthy,
  unknown,
}

/// Health check result
class HealthCheckResult {
  final String name;
  final HealthStatus status;
  final String message;
  final Map<String, dynamic>? details;
  final Duration? responseTime;
  final DateTime timestamp;

  HealthCheckResult({
    required this.name,
    required this.status,
    required this.message,
    this.details,
    this.responseTime,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Check if healthy
  bool get isHealthy => status == HealthStatus.healthy;

  /// Check if degraded
  bool get isDegraded => status == HealthStatus.degraded;

  /// Check if unhealthy
  bool get isUnhealthy => status == HealthStatus.unhealthy;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'status': status.name,
      'message': message,
      'details': details,
      'responseTime': responseTime?.inMilliseconds,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Health check interface
abstract class HealthCheck {
  /// Health check name
  String get name;

  /// Health check description
  String get description;

  /// Perform the health check
  Future<HealthCheckResult> check();
}

/// Simple health check implementation
class SimpleHealthCheck implements HealthCheck {
  final String _name;
  final String _description;
  final Future<HealthCheckResult> Function() _checkFunction;

  SimpleHealthCheck({
    required String name,
    required String description,
    required Future<HealthCheckResult> Function() checkFunction,
  }) : _name = name,
       _description = description,
       _checkFunction = checkFunction;

  @override
  String get name => _name;

  @override
  String get description => _description;

  @override
  Future<HealthCheckResult> check() async {
    return await _checkFunction();
  }
}

/// Health checker for managing and running health checks
class HealthChecker {
  static final HealthChecker _instance = HealthChecker._internal();

  factory HealthChecker() => _instance;

  HealthChecker._internal();

  final Map<String, HealthCheck> _checks = {};
  final EventBus _eventBus = EventBus();
  final Map<String, HealthCheckResult> _lastResults = {};
  Timer? _periodicTimer;
  Duration _checkInterval = const Duration(minutes: 1);
  bool _enabled = true;

  /// Check if health checking is enabled
  bool get isEnabled => _enabled;

  /// Get check interval
  Duration get checkInterval => _checkInterval;

  /// Get all registered health checks
  Map<String, HealthCheck> get checks => Map.unmodifiable(_checks);

  /// Get last health check results
  Map<String, HealthCheckResult> get lastResults => Map.unmodifiable(_lastResults);

  /// Enable health checking
  void enable() {
    _enabled = true;
  }

  /// Disable health checking
  void disable() {
    _enabled = false;
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Set check interval and restart periodic checking
  void setCheckInterval(Duration interval) {
    _checkInterval = interval;
    if (_enabled && _periodicTimer != null) {
      _periodicTimer?.cancel();
      _startPeriodicChecks();
    }
  }

  /// Register a health check
  void registerCheck(HealthCheck check) {
    _checks[check.name] = check;
  }

  /// Unregister a health check
  void unregisterCheck(String name) {
    _checks.remove(name);
    _lastResults.remove(name);
  }

  /// Run a specific health check
  Future<HealthCheckResult> runCheck(String name) async {
    final check = _checks[name];
    if (check == null) {
      throw ActionFailedException(
        'Health check not found: $name',
        moduleId: 'HealthChecker',
        correlationId: null,
      );
    }

    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await check.check();
      stopwatch.stop();
      
      final resultWithTime = HealthCheckResult(
        name: result.name,
        status: result.status,
        message: result.message,
        details: result.details,
        responseTime: stopwatch.elapsed,
        timestamp: result.timestamp,
      );

      _lastResults[name] = resultWithTime;
      
      _eventBus.emit(StatusUpdateEvent(
        level: _getStatusLevel(resultWithTime.status),
        message: 'Health check ${resultWithTime.name}: ${resultWithTime.status.name}',
        moduleId: 'HealthChecker',
        metadata: resultWithTime.toMap(),
      ));

      return resultWithTime;
    } catch (e) {
      stopwatch.stop();
      
      final errorResult = HealthCheckResult(
        name: name,
        status: HealthStatus.unhealthy,
        message: 'Health check failed: ${e.toString()}',
        responseTime: stopwatch.elapsed,
      );

      _lastResults[name] = errorResult;

      _eventBus.emit(StatusUpdateEvent(
        level: StatusEvent.error,
        message: 'Health check ${name} failed: ${e.toString()}',
        moduleId: 'HealthChecker',
        metadata: errorResult.toMap(),
      ));

      return errorResult;
    }
  }

  /// Run all health checks
  Future<Map<String, HealthCheckResult>> runAllChecks() async {
    final results = <String, HealthCheckResult>{};
    
    for (final name in _checks.keys) {
      try {
        results[name] = await runCheck(name);
      } catch (e) {
        results[name] = HealthCheckResult(
          name: name,
          status: HealthStatus.unhealthy,
          message: 'Health check failed: ${e.toString()}',
        );
      }
    }

    return results;
  }

  /// Get overall system health
  HealthStatus getOverallHealth() {
    if (_lastResults.isEmpty) return HealthStatus.unknown;

    final statuses = _lastResults.values.map((r) => r.status).toList();
    
    if (statuses.any((s) => s == HealthStatus.unhealthy)) {
      return HealthStatus.unhealthy;
    }
    
    if (statuses.any((s) => s == HealthStatus.degraded)) {
      return HealthStatus.degraded;
    }
    
    if (statuses.every((s) => s == HealthStatus.healthy)) {
      return HealthStatus.healthy;
    }
    
    return HealthStatus.unknown;
  }

  /// Get health summary
  Map<String, dynamic> getHealthSummary() {
    final overall = getOverallHealth();
    final results = _lastResults.values.toList();
    
    final healthy = results.where((r) => r.isHealthy).length;
    final degraded = results.where((r) => r.isDegraded).length;
    final unhealthy = results.where((r) => r.isUnhealthy).length;
    final unknown = results.where((r) => r.status == HealthStatus.unknown).length;

    return {
      'overall': overall.name,
      'total': results.length,
      'healthy': healthy,
      'degraded': degraded,
      'unhealthy': unhealthy,
      'unknown': unknown,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Get detailed health report
  Map<String, dynamic> getDetailedReport() {
    return {
      'summary': getHealthSummary(),
      'checks': _lastResults.map((name, result) => MapEntry(name, result.toMap())),
    };
  }

  /// Start periodic health checks
  void startPeriodicChecks() {
    if (!_enabled) return;
    
    _startPeriodicChecks();
  }

  /// Stop periodic health checks
  void stopPeriodicChecks() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Start periodic checks
  void _startPeriodicChecks() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(_checkInterval, (_) {
      runAllChecks();
    });
  }

  /// Convert health status to status event level
  StatusEvent _getStatusLevel(HealthStatus status) {
    switch (status) {
      case HealthStatus.healthy:
        return StatusEvent.info;
      case HealthStatus.degraded:
        return StatusEvent.warning;
      case HealthStatus.unhealthy:
        return StatusEvent.error;
      case HealthStatus.unknown:
        return StatusEvent.warning;
    }
  }

  /// Clear all health checks and results
  void clear() {
    _checks.clear();
    _lastResults.clear();
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }
}
