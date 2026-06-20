import 'dart:async';
import 'dart:collection';

import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/utils/event_bus.dart';

/// Performance metric types
enum MetricType {
  counter,
  gauge,
  histogram,
  timer,
}

/// Performance metric data
class MetricData {
  final String name;
  final MetricType type;
  final double value;
  final DateTime timestamp;
  final Map<String, String>? tags;

  const MetricData({
    required this.name,
    required this.type,
    required this.value,
    required this.timestamp,
    this.tags,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type.name,
      'value': value,
      'timestamp': timestamp.toIso8601String(),
      'tags': tags,
    };
  }
}

/// Performance counter for counting events
class Counter {
  final String name;
  final Map<String, String>? tags;
  double _value = 0.0;
  final List<MetricData> _history = [];

  Counter({required this.name, this.tags});

  /// Current value
  double get value => _value;

  /// Increment counter
  void increment([double amount = 1.0]) {
    _value += amount;
    _recordMetric(MetricType.counter, _value);
  }

  /// Reset counter
  void reset() {
    _value = 0.0;
  }

  /// Get metric history
  List<MetricData> get history => List.unmodifiable(_history);

  void _recordMetric(MetricType type, double value) {
    _history.add(MetricData(
      name: name,
      type: type,
      value: value,
      timestamp: DateTime.now(),
      tags: tags,
    ));
  }
}

/// Performance gauge for measuring current values
class Gauge {
  final String name;
  final Map<String, String>? tags;
  double _value = 0.0;
  final List<MetricData> _history = [];

  Gauge({required this.name, this.tags});

  /// Current value
  double get value => _value;

  /// Set gauge value
  void set(double value) {
    _value = value;
    _recordMetric(MetricType.gauge, _value);
  }

  /// Get metric history
  List<MetricData> get history => List.unmodifiable(_history);

  void _recordMetric(MetricType type, double value) {
    _history.add(MetricData(
      name: name,
      type: type,
      value: value,
      timestamp: DateTime.now(),
      tags: tags,
    ));
  }
}

/// Performance histogram for measuring distributions
class Histogram {
  final String name;
  final Map<String, String>? tags;
  final List<double> _values = [];
  final List<MetricData> _history = [];

  Histogram({required this.name, this.tags});

  /// Record a value
  void record(double value) {
    _values.add(value);
    _recordMetric(MetricType.histogram, value);
  }

  /// Get current values
  List<double> get values => List.unmodifiable(_values);

  /// Get count of recorded values
  int get count => _values.length;

  /// Get minimum value
  double get min => _values.isEmpty ? 0.0 : _values.reduce((a, b) => a < b ? a : b);

  /// Get maximum value
  double get max => _values.isEmpty ? 0.0 : _values.reduce((a, b) => a > b ? a : b);

  /// Get average value
  double get average => _values.isEmpty ? 0.0 : _values.reduce((a, b) => a + b) / _values.length;

  /// Get percentile value
  double percentile(double p) {
    if (_values.isEmpty) return 0.0;
    final sorted = List<double>.from(_values)..sort();
    final index = (p / 100 * (sorted.length - 1)).round();
    return sorted[index];
  }

  /// Get metric history
  List<MetricData> get history => List.unmodifiable(_history);

  void _recordMetric(MetricType type, double value) {
    _history.add(MetricData(
      name: name,
      type: type,
      value: value,
      timestamp: DateTime.now(),
      tags: tags,
    ));
  }
}

/// Performance timer for measuring durations
class Timer {
  final String name;
  final Map<String, String>? tags;
  final List<Duration> _durations = [];
  final List<MetricData> _history = [];

  Timer({required this.name, this.tags});

  /// Record a duration
  void record(Duration duration) {
    _durations.add(duration);
    _recordMetric(MetricType.timer, duration.inMicroseconds.toDouble());
  }

  /// Get current durations
  List<Duration> get durations => List.unmodifiable(_durations);

  /// Get count of recorded durations
  int get count => _durations.length;

  /// Get minimum duration
  Duration get min => _durations.isEmpty 
      ? Duration.zero 
      : _durations.reduce((a, b) => a < b ? a : b);

  /// Get maximum duration
  Duration get max => _durations.isEmpty 
      ? Duration.zero 
      : _durations.reduce((a, b) => a > b ? a : b);

  /// Get average duration
  Duration get average {
    if (_durations.isEmpty) return Duration.zero;
    final total = _durations.fold<Duration>(
      Duration.zero, 
      (sum, duration) => sum + duration,
    );
    return Duration(microseconds: total.inMicroseconds ~/ _durations.length);
  }

  /// Get metric history
  List<MetricData> get history => List.unmodifiable(_history);

  void _recordMetric(MetricType type, double value) {
    _history.add(MetricData(
      name: name,
      type: type,
      value: value,
      timestamp: DateTime.now(),
      tags: tags,
    ));
  }
}

/// Performance monitor for collecting and managing metrics
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();

  factory PerformanceMonitor() => _instance;

  PerformanceMonitor._internal();

  final Map<String, Counter> _counters = {};
  final Map<String, Gauge> _gauges = {};
  final Map<String, Histogram> _histograms = {};
  final Map<String, Timer> _timers = {};
  final EventBus _eventBus = EventBus();
  final Queue<MetricData> _recentMetrics = Queue<MetricData>();
  final int _maxRecentMetrics = 1000;
  bool _enabled = true;

  /// Check if monitoring is enabled
  bool get isEnabled => _enabled;

  /// Enable monitoring
  void enable() {
    _enabled = true;
  }

  /// Disable monitoring
  void disable() {
    _enabled = false;
  }

  /// Get or create a counter
  Counter counter(String name, {Map<String, String>? tags}) {
    final key = _makeKey(name, tags);
    return _counters.putIfAbsent(key, () => Counter(name: name, tags: tags));
  }

  /// Get or create a gauge
  Gauge gauge(String name, {Map<String, String>? tags}) {
    final key = _makeKey(name, tags);
    return _gauges.putIfAbsent(key, () => Gauge(name: name, tags: tags));
  }

  /// Get or create a histogram
  Histogram histogram(String name, {Map<String, String>? tags}) {
    final key = _makeKey(name, tags);
    return _histograms.putIfAbsent(key, () => Histogram(name: name, tags: tags));
  }

  /// Get or create a timer
  Timer timer(String name, {Map<String, String>? tags}) {
    final key = _makeKey(name, tags);
    return _timers.putIfAbsent(key, () => Timer(name: name, tags: tags));
  }

  /// Time an operation
  Future<T> timeOperation<T>(
    String name,
    Future<T> Function() operation, {
    Map<String, String>? tags,
  }) async {
    if (!_enabled) return await operation();

    final timer = this.timer(name, tags: tags);
    final stopwatch = Stopwatch()..start();

    try {
      final result = await operation();
      timer.record(stopwatch.elapsed);
      return result;
    } catch (e) {
      timer.record(stopwatch.elapsed);
      rethrow;
    }
  }

  /// Time a synchronous operation
  T timeSyncOperation<T>(
    String name,
    T Function() operation, {
    Map<String, String>? tags,
  }) {
    if (!_enabled) return operation();

    final timer = this.timer(name, tags: tags);
    final stopwatch = Stopwatch()..start();

    try {
      final result = operation();
      timer.record(stopwatch.elapsed);
      return result;
    } catch (e) {
      timer.record(stopwatch.elapsed);
      rethrow;
    }
  }

  /// Record a metric
  void recordMetric(MetricData metric) {
    if (!_enabled) return;

    _recentMetrics.add(metric);
    if (_recentMetrics.length > _maxRecentMetrics) {
      _recentMetrics.removeFirst();
    }

    _eventBus.emit(PerformanceEvent(
      operation: metric.name,
      duration: Duration(microseconds: metric.value.round()),
      moduleId: 'PerformanceMonitor',
      metadata: {
        'type': metric.type.name,
        'value': metric.value,
        'tags': metric.tags,
      },
    ));
  }

  /// Get all counters
  Map<String, Counter> get counters => Map.unmodifiable(_counters);

  /// Get all gauges
  Map<String, Gauge> get gauges => Map.unmodifiable(_gauges);

  /// Get all histograms
  Map<String, Histogram> get histograms => Map.unmodifiable(_histograms);

  /// Get all timers
  Map<String, Timer> get timers => Map.unmodifiable(_timers);

  /// Get recent metrics
  List<MetricData> get recentMetrics => List.unmodifiable(_recentMetrics);

  /// Get performance summary
  Map<String, dynamic> getSummary() {
    return {
      'enabled': _enabled,
      'counters': _counters.length,
      'gauges': _gauges.length,
      'histograms': _histograms.length,
      'timers': _timers.length,
      'recentMetrics': _recentMetrics.length,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Get detailed metrics report
  Map<String, dynamic> getDetailedReport() {
    final report = <String, dynamic>{
      'summary': getSummary(),
      'counters': {},
      'gauges': {},
      'histograms': {},
      'timers': {},
    };

    for (final entry in _counters.entries) {
      report['counters'][entry.key] = {
        'value': entry.value.value,
        'history': entry.value.history.map((m) => m.toMap()).toList(),
      };
    }

    for (final entry in _gauges.entries) {
      report['gauges'][entry.key] = {
        'value': entry.value.value,
        'history': entry.value.history.map((m) => m.toMap()).toList(),
      };
    }

    for (final entry in _histograms.entries) {
      final h = entry.value;
      report['histograms'][entry.key] = {
        'count': h.count,
        'min': h.min,
        'max': h.max,
        'average': h.average,
        'p50': h.percentile(50),
        'p95': h.percentile(95),
        'p99': h.percentile(99),
        'history': h.history.map((m) => m.toMap()).toList(),
      };
    }

    for (final entry in _timers.entries) {
      final t = entry.value;
      report['timers'][entry.key] = {
        'count': t.count,
        'min': t.min.inMicroseconds,
        'max': t.max.inMicroseconds,
        'average': t.average.inMicroseconds,
        'history': t.history.map((m) => m.toMap()).toList(),
      };
    }

    return report;
  }

  /// Clear all metrics
  void clear() {
    _counters.clear();
    _gauges.clear();
    _histograms.clear();
    _timers.clear();
    _recentMetrics.clear();
  }

  /// Create a unique key for metrics
  String _makeKey(String name, Map<String, String>? tags) {
    if (tags == null || tags.isEmpty) return name;
    
    final sortedTags = Map.fromEntries(
      tags.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    
    final tagString = sortedTags.entries
        .map((e) => '${e.key}=${e.value}')
        .join(',');
    
    return '$name{$tagString}';
  }
}
