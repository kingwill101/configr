import 'package:configr/src/multi_host/host.dart' show Host;

/// Role model representing host deployment roles in a multi-host architecture.
///
/// Roles are used to group hosts with similar responsibilities and to
/// control execution order. Each role has a priority and can serve as the
/// primary deployment target (e.g., web servers boot first, then workers).
///
/// This model supports both Kamal-style deployment (boot groups) and
/// traditional multi-tier architectures (web -> proxy -> worker -> db).
///
/// Roles enable two important deployment patterns:
/// 1. **Boot groups** - Zero-downtime serial deployment of interdependent services
/// 2. **Deployment strategy** - Linear, parallel, or serial execution based on roles
class Role {
  /// User-defined role name identifying the service type or tier.
  ///
  /// Examples: "web", "worker", "db", "proxy", "redis", "nginx"
  /// Used for filtering hosts: hostsWithRole("web")
  final String name;

  /// Hosts assigned to this role.
  ///
  /// All hosts that perform the same service function (e.g., all web servers).
  /// Can be empty - meaning role exists but no hosts configured yet.
  final List<Host> hosts;

  /// Whether this role is considered the primary service.
  ///
  /// Primary roles have special requirements in serial deployment:
  /// - Determine initial deployment order (boot groups)
  /// - Act as service validation points (health checks before continuing)
  /// - Used for deployment kickoff and final rollback
  final bool primary;

  /// Priority for boot order in serial deployment.
  ///
  /// Lower values get booted first (1 = web frontend, 10 = background jobs).
  /// Combined with role name for deterministic ordering.
  ///
  /// Purpose:
  /// - Zero-downtime deployments: web -> proxy -> worker -> db
  /// - Resource dependency ordering: app servers before databases
  /// - Dependency validation: wait for role completion before next
  final int bootPriority;

  /// Optional boot group name for serial strategy coordination.
  ///
  /// When multiple roles belong to the same boot group, they can be
  /// deployed in parallel before moving to the next boot group.
  /// Equivalent to Kamal's boot groups.
  final String? bootGroupName;

  const Role({
    required this.name,
    this.hosts = const [],
    this.primary = false,
    this.bootPriority = 99,
    this.bootGroupName,
  });

  /// Are any hosts assigned to this role?
  bool get hasHosts => hosts.isNotEmpty;

  /// Get host count for status reporting and resource planning.
  int get hostCount => hosts.length;

  /// Display-friendly string representation.
  @override
  String toString() {
    return 'Role(name: $name, hosts: $hostCount, primary: $primary, priority: $bootPriority)';
  }

  /// Equality comparison based on role name.
  ///
  /// Two roles with the same name are considered equal (assuming unique
  /// role names in inventory). Useful for deduplication and lookup.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Role && other.name == name);

  @override
  int get hashCode => name.hashCode;
}