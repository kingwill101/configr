import 'package:configr/src/multi_host/host.dart' show Host;

/// Represents a target host for execution in multi-host operations.
///
/// A Target is a Host augmented with execution-specific metadata,
/// including the execution strategy and optional priority.
class Target {
  /// The host to execute this target on.
  final Host host;

  /// Execution strategy for this target.
  final String strategy;

  /// Boot group priority for serial execution.
  final int? priority;

  /// Create a target with a host and strategy.
  Target({
    required this.host,
    required this.strategy,
    this.priority,
  });

  /// Create a target with host, strategy, and boot group.
  factory Target.withBootGroup({
    required Host host,
    required String strategy,
    required int priority,
  }) {
    return Target(
      host: host,
      strategy: strategy,
      priority: priority,
    );
  }

  /// Create a target with host and strategy using host roles as priority.
  factory Target.withRolePriority({
    required Host host,
    required String strategy,
  }) {
    final rolePriority = _calculatePriorityFromRoles(host);
    return Target(
      host: host,
      strategy: strategy,
      priority: rolePriority,
    );
  }

  static int _calculatePriorityFromRoles(Host host) {
    final rolePriority = <String, int>{
      'web': 1,
      'proxy': 1,
      'loadbalayer': 2,
      'application': 2,
      'app': 2,
      'database': 10,
      'db': 10,
      'redis': 10,
      'cache': 10,
      'worker': 20,
      'job': 20,
      'batch': 20,
      'cron': 20,
      '_default': 99,
    };

    for (final role in host.roles) {
      if (rolePriority.containsKey(role)) {
        return rolePriority[role]!;
      }
    }

    return 99;
  }

  /// Is this target a primary service?
  bool get isPrimary => host.roles.contains('web') || host.roles.contains('application');

  @override
  String toString() {
    return 'Target(host: ${host.name}, strategy: $strategy, priority: $priority)';
  }
}
