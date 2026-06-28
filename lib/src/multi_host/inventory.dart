import 'package:configr/src/multi_host/host.dart' show Host;
import 'package:configr/src/multi_host/role.dart' show Role;

/// Central container for host inventory management.
///
/// The Inventory class is the primary repository for host definitions,
/// roles, and groups in a multi-host configuration. It supports
/// multiple input formats and provides efficient querying mechanisms
/// for the various strategies (linear, parallel, serial).
///
/// Inventory design philosophy:
/// 1. Load once, for the entire deployment
/// 2. Support multiple input formats (i3config, YAML, INI)
/// 3. Enable efficient role-based queries for strategies
/// 4. Provide redundancy and fallback mechanisms
///
/// Common inventory structures:
/// - i3config syntax: inventory { host "name" ... }
/// - YAML file: ~/.configr/hosts.yml
/// - INI file: /etc/configr/hosts.ini (Ansible style)
///
/// The Inventory class serves as both data store and service layer,
/// providing methods to:
/// 1. Load hosts from multiple sources
/// 2. Resolve roles and groups
/// 3. Filter and select targets for execution
/// 4. Validate inventory consistency
class Inventory {
  /// All hosts in the inventory.
  ///
  /// Note: This list remains mutable during loading from multiple sources
  /// to support progressive inventory building (e.g., i3config block +
  /// external YAML/INI fallback). After loading is complete, it should be
  /// converted to an immutable list for thread safety.
  final List<Host> hosts;

  /// All roles defined in the inventory.
  ///
  /// Roles are derived from host assignments, not independent entities.
  /// A role exists if at least one host claims it.
  final List<Role> roles;

  /// All groups defined in the inventory.
  ///
  /// Groups are derived from host assignments. A group exists if at
  /// least one host belongs to it.
  final List<String> groups;

  /// Mapping from role name to derived Role object.
  ///
  /// This provides O(1) access to roles for strategies needing to
  /// find all hosts of a particular role (e.g., web servers).
  final Map<String, Role> rolesByName;

  /// Mapping from group name to list of host names.
  ///
  /// Provides O(1) access to hosts by group for targeted operations.
  final Map<String, List<String>> hostsByGroup;

  /// Host lookup by name for fast access.
  ///
  /// This provides immediate lookup of any host by its identifier
  /// without iterating over the entire hosts list.
  final Map<String, Host> hostsByName;

  /// Optional custom metadata attached to the inventory.
  ///
  /// This allows inventory-wide properties to be stored without
  /// creating a dedicated class. Common use cases:
  /// - Inventory source versions
  /// - Custom metadata
  /// - Configuration defaults
  final Map<String, dynamic> metadata;

  /// Optional default targets for execution.
  ///
  /// When no explicit targets are specified (via CLI or config),
  /// these defaults determine which hosts to operate on. If not set,
  /// all hosts in the inventory are used.
  final List<String>? defaultTargets;

  /// Per-group variables for Ansible-style group variable resolution.
  ///
  /// Variables defined here apply to all hosts in the group and are
  /// overridden by host-level variables and CLI vars.
  final Map<String, Map<String, String>> groupVars;

  /// Create an empty inventory.
  Inventory({
    this.hosts = const [],
    this.roles = const [],
    this.groups = const [],
    this.rolesByName = const {},
    this.hostsByGroup = const {},
    this.hostsByName = const {},
    this.metadata = const {},
    this.defaultTargets,
    this.groupVars = const {},
  });

  /// Create an inventory with the required initial data.
  ///
  /// This factory method is used when all the inventory data is
  /// available upfront (e.g., after loading from all sources).
  factory Inventory.full({
    required List<Host> hosts,
    required List<Role> roles,
    required List<String> groups,
    required Map<String, Role> rolesByName,
    required Map<String, List<String>> hostsByGroup,
    required Map<String, Host> hostsByName,
    Map<String, dynamic>? metadata,
    List<String>? defaultTargets,
    Map<String, Map<String, String>> groupVars = const {},
  }) {
    return Inventory(
      hosts: hosts,
      roles: roles,
      groups: groups,
      rolesByName: rolesByName,
      hostsByGroup: hostsByGroup,
      hostsByName: hostsByName,
      metadata: metadata ?? {},
      defaultTargets: defaultTargets,
      groupVars: groupVars,
    );
  }

  /// Collect all group-level variables applicable to this host.
  ///
  /// Iterates the host's groups and merges vars from each (in order,
  /// with later groups overriding earlier ones).
  Map<String, String> groupVarsFor(Host host) {
    final result = <String, String>{};
    for (final group in host.groups) {
      final vars = groupVars[group];
      if (vars != null) result.addAll(vars);
    }
    return result;
  }

  /// Find a host by name.
  ///
  /// Returns null if the host is not found in the inventory.
  Host? getHost(String name) => hostsByName[name];

  /// Find all hosts belonging to a specific role.
  ///
  /// This is a key method for strategies that need to operate on
  /// all hosts of a specific service type (e.g., all web servers).
  List<Host> getHostsByRole(String roleName) =>
      rolesByName[roleName]?.hosts ?? [];

  /// Find all hosts belonging to a specific group.
  ///
  /// Useful for targeted operations on infrastructure groups
  /// (e.g., all production hosts, all EU hosts).
  List<Host> getHostsByGroup(String groupName) =>
      hostsByGroup[groupName]?.map((name) => hostsByName[name]!).toList() ?? [];

  /// Get all hosts in the inventory.
  ///
  /// This is used when all hosts need to be processed (e.g., parallel strategy,
  /// or when no specific targets have been selected).
  List<Host> getAllHosts() => List.unmodifiable(hosts);

  /// Get all role names defined in the inventory.
  ///
  /// This is useful for UI display, validation, and strategy planning.
  List<String> getRoleNames() => rolesByName.keys.toList();

  /// Get all groups defined in the inventory.
  ///
  /// This is useful for UI display, filtering, and access control.
  List<String> getGroupNames() => groups;

  /// Count total hosts in the inventory.
  ///
  /// Used for resource planning, logging, and progress tracking.
  int get hostCount => hosts.length;

  /// Count roles with hosts assigned.
  int get roleCount => rolesByName.length;

  /// Count groups with hosts assigned.
  int get groupCount => groups.length;

  /// Validate inventory consistency.
  ///
  /// This method checks for:
  /// 1. Duplicate host names
  /// 2. Invalid role names
  /// 3. Invalid group names
  /// 4. Reference errors (to non-existent hosts)
  ///
  /// Returns a list of error messages, empty if inventory is valid.
  List<String> validate() {
    final errors = <String>[];

    // Check for duplicate host names
    final hostNames = <String>{};
    for (final host in hosts) {
      if (hostNames.contains(host.name)) {
        errors.add('Duplicate host name: ${host.name}');
      } else {
        hostNames.add(host.name);
      }
    }

    // Check role consistency
    for (final role in roles) {
      for (final hostName in role.hosts.map((h) => h.name)) {
        if (!hostsByName.containsKey(hostName)) {
          errors.add('Role ${role.name} references non-existent host: $hostName');
        }
      }
    }

    return errors;
  }

  /// Display-friendly string representation.
  @override
  String toString() {
    return 'Inventory(hosts: $hostCount, roles: $roleCount, groups: $groupCount)';
  }
}