import 'package:configr/src/cli/cli_exit_exception.dart';
import 'package:configr/src/multi_host/host.dart' show Host;
import 'package:configr/src/multi_host/inventory.dart' show Inventory;
import 'package:configr/src/multi_host/target.dart' show Target;

/// Resolves target hosts based on various selection criteria.
///
/// The TargetResolver centralizes host selection logic for multi-host
/// operations, supporting multiple input sources in order of precedence:
/// 1. Explicit host/group/role selections (highest priority)
/// 2. Inventory default targets (if defined)
/// 3. All available hosts (final fallback)
///
/// This abstraction isolates the host selection complexity, making it easier
/// to test and maintain the multi-host logic.
///
/// Common use cases:
/// - Select specific hosts: configr apply --host web-01,db-01
/// - Select by role: configr apply --role web,worker
/// - Select by group: configr apply --group production
/// - Default behavior: inventory configuration
class TargetResolver {
  /// Resolve target hosts based on selection criteria.
  ///
  /// Resolution order:
  /// 1. Explicit host names in [hosts] (highest priority)
  /// 2. Explicit role names in [roles] (if hosts not specified)
  /// 3. Explicit group names in [groups] (if hosts and roles not specified)
  /// 4. Inventory default targets (if defined)
  /// 5. All hosts in inventory (final fallback)
  ///
  /// Returns empty list if inventory is empty and no explicit selection.
  ///
  /// Parameters:
  /// - [hosts]: Optional list of host names to select by name
  /// - [roles]: Optional list of role names to select by role
  /// - [groups]: Optional list of group names to select by group
  /// - [inventory]: The inventory containing hosts, roles, and groups
  /// - [throwIfNotFound]: Whether to throw an error if selected targets
  ///                    are not found in inventory (useful for CLI tools)
  ///
  /// Returns:
  /// A list of Host objects matching the selection criteria.
  ///
  /// Example:
  /// ```dart
  /// final inventory = Inventory.full(...);
  /// final hosts = resolver.resolve(
  ///   hosts: ['web-01', 'web-02'],
  ///   inventory: inventory,
  /// );
  /// ```
  ///
  /// Example (by role):
  /// ```dart
  /// final hosts = resolver.resolve(
  ///   roles: ['web', 'worker'],
  ///   inventory: inventory,
  /// );
  /// // Returns all hosts with role 'web' or 'worker'
  /// ```
  List<Host> resolve({
    List<String>? hosts,
    List<String>? roles,
    List<String>? groups,
    required Inventory inventory,
    bool throwIfNotFound = false,
  }) {
    // Handle explicit host selection (highest priority)
    if (hosts != null && hosts.isNotEmpty) {
      return _resolveByName(hosts, inventory, throwIfNotFound);
    }

    // Handle role-based selection (second priority)
    if (roles != null && roles.isNotEmpty) {
      return _resolveByRole(roles, inventory);
    }

    // Handle group-based selection (third priority)
    if (groups != null && groups.isNotEmpty) {
      return _resolveByGroup(groups, inventory);
    }

    // Use inventory defaults (fourth priority)
    if (inventory.defaultTargets != null &&
        inventory.defaultTargets!.isNotEmpty) {
      return _resolveByName(
        inventory.defaultTargets!,
        inventory,
        throwIfNotFound,
      );
    }

    // Fallback to all hosts (final option)
    return inventory.getAllHosts();
  }

  /// Resolve hosts by explicit names.
  ///
  /// Parameters:
  /// - [hostNames]: Names of hosts to resolve
  /// - [inventory]: The inventory to search in
  /// - [throwIfNotFound]: Whether to throw an error for non-existent hosts
  ///
  /// Returns:
  /// List of Host objects with matching names.
  ///
  /// Throws:
  /// ConfigrCliExitException if [throwIfNotFound] is true and any host
  /// name is not found in the inventory.
  List<Host> _resolveByName(
    List<String> hostNames,
    Inventory inventory,
    bool throwIfNotFound,
  ) {
    final result = <Host>[];
    final missing = <String>[];

    for (final name in hostNames) {
      final host = inventory.getHost(name);
      if (host != null) {
        result.add(host);
      } else {
        missing.add(name);
      }
    }

    if (throwIfNotFound && missing.isNotEmpty) {
      throw CliExitException(1);
    }

    return result;
  }

  /// Resolve hosts by role assignment.
  ///
  /// Parameters:
  /// - [roleNames]: Names of roles to select hosts by
  /// - [inventory]: The inventory to search in
  ///
  /// Returns:
  /// Combined list of all hosts assigned to the specified roles.
  /// Duplicate hosts are avoided (a host can belong to multiple roles).
  List<Host> _resolveByRole(List<String> roleNames, Inventory inventory) {
    final hosts = <Host>{}; // Use Set to avoid duplicates

    for (final roleName in roleNames) {
      final roleHosts = inventory.getHostsByRole(roleName);
      for (final host in roleHosts) {
        hosts.add(host);
      }
    }

    return hosts.toList();
  }

  /// Resolve hosts by group membership.
  ///
  /// Parameters:
  /// - [groupNames]: Names of groups to select hosts by
  /// - [inventory]: The inventory to search in
  ///
  /// Returns:
  /// Combined list of all hosts belonging to the specified groups.
  /// Duplicate hosts are avoided (a host can belong to multiple groups).
  List<Host> _resolveByGroup(List<String> groupNames, Inventory inventory) {
    final hosts = <Host>{}; // Use Set to avoid duplicates

    for (final groupName in groupNames) {
      final groupHosts = inventory.getHostsByGroup(groupName);
      for (final host in groupHosts) {
        hosts.add(host);
      }
    }

    return hosts.toList();
  }

  /// Build a Target object from a Host.
  ///
  /// Parameters:
  /// - [host]: The source host
  /// - [strategy]: Optional execution strategy (overrides inventory defaults)
  /// - [priority]: Optional boot priority (for serial strategy)
  ///
  /// Returns:
  /// A Target object configured with the host's properties and options.
  Target fromHost({
    required Host host,
    required String strategy,
    int? priority,
  }) {
    return Target(host: host, strategy: strategy, priority: priority);
  }

  /// Build targets for a list of hosts with optional strategy overrides.
  ///
  /// This is a convenience method for the common case where all targets
  /// use the same strategy.
  ///
  /// Parameters:
  /// - [hosts]: List of hosts to convert to targets
  /// - [strategy]: Default strategy for all targets
  /// - [priority]: Optional priority (same for all targets)
  ///
  /// Returns:
  /// List of Target objects.
  List<Target> fromHosts(List<Host> hosts, String strategy, {int? priority}) {
    return hosts
        .map(
          (host) =>
              fromHost(host: host, strategy: strategy, priority: priority),
        )
        .toList();
  }
}
