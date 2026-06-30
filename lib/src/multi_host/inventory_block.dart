import 'dart:async';
import 'dart:io';

import 'package:i3config/i3config_v2.dart' as i3;
import 'package:configr/src/multi_host/host.dart' show Host;
import 'package:configr/src/multi_host/role.dart' show Role;
import 'package:configr/src/multi_host/inventory.dart' show Inventory;

/// Block handler for `inventory { ... }` sections.
///
/// Parses inventory configuration and makes it available to strategies
/// via `context.globalContext.options`.
///
/// Example:
/// ```i3
/// inventory {
///   default_targets = ["web-01", "db-01"]
///   host "web-01" { address = "10.0.0.1"; roles = ["web"] }
///   host "web-02" { address = "10.0.0.2"; roles = ["web"] }
/// }
/// ```
class InventoryBlock extends i3.BaseBlockHandler {
  @override
  String get blockType => 'inventory';

  @override
  FutureOr<void> handle(i3.Block block, i3.Context context) {}

  @override
  FutureOr<void> afterChildrenProcessed(
    i3.Block block,
    i3.Context context,
  ) async {
    final hosts = <Host>[];
    final hostsByName = <String, Host>{};
    final rolesByName = <String, Role>{};
    final hostsByGroup = <String, List<String>>{};
    final groups = <String>[];

    final hostRegistry = context.globalContext.blockRegistry['host'];
    if (hostRegistry != null) {
      for (final entry in hostRegistry.entries) {
        final name = entry.key;
        if (name == null || name.isEmpty) continue;

        final vars = entry.value;
        final address = vars['address'] as String? ?? '';
        final portStr = vars['port'] as String?;
        final username = vars['username'] as String?;
        var privateKey = vars['privateKey'] as String?;
        if (privateKey != null && File(privateKey).existsSync()) {
          privateKey = File(privateKey).readAsStringSync();
        }
        final rolesRaw = vars['roles'];
        final groupsRaw = vars['groups'];

        final List<String> roles;
        if (rolesRaw is List) {
          roles = rolesRaw.cast<String>();
        } else if (rolesRaw is String) {
          roles = rolesRaw
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        } else {
          roles = [];
        }

        final List<String> hostGroups;
        if (groupsRaw is List) {
          hostGroups = groupsRaw.cast<String>();
        } else if (groupsRaw is String) {
          hostGroups = groupsRaw
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        } else {
          hostGroups = [];
        }

        final host = Host(
          name: name,
          address: address,
          port: int.tryParse(portStr ?? '') ?? 22,
          username: username ?? 'root',
          privateKey: privateKey,
          roles: roles,
          groups: hostGroups,
        );

        hosts.add(host);
        hostsByName[name] = host;

        for (final role in roles) {
          rolesByName
              .putIfAbsent(role, () => Role(name: role, hosts: []))
              .hosts
              .add(host);
        }
        for (final group in hostGroups) {
          if (!groups.contains(group)) groups.add(group);
          hostsByGroup.putIfAbsent(group, () => []).add(host.name);
        }
      }
    }

    final defaultTargetsRaw = context.getVariable('default_targets');

    final List<String>? defaultTargets;
    if (defaultTargetsRaw is List) {
      defaultTargets = defaultTargetsRaw.cast<String>();
    } else if (defaultTargetsRaw is String) {
      defaultTargets = defaultTargetsRaw
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else {
      defaultTargets = null;
    }

    final inventory = Inventory.full(
      hosts: hosts,
      roles: rolesByName.values.toList(),
      groups: groups,
      rolesByName: rolesByName,
      hostsByGroup: hostsByGroup,
      hostsByName: hostsByName,
      defaultTargets: defaultTargets,
    );

    context.globalContext.options['_inventory'] = inventory;
  }
}
