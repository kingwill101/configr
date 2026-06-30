import 'package:configr/src/multi_host/inventory.dart' show Inventory;
import 'package:configr/src/utils/logging.dart';
import 'base_command.dart';

class HostsCommand extends BaseCommand {
  @override
  String get name => 'hosts';

  @override
  String get description => 'List inventory hosts, roles, and groups';

  @override
  Future<void> executeCommand() async {
    io.title('Host Inventory');

    try {
      final resolved = await runtime.resolveConfig();
      if (resolved == null) {
        io.error('Configuration file not found.');
        return;
      }

      final inventory = resolved.inventory;
      if (inventory == null) {
        io.warn('No inventory defined (add an inventory or servers block).');
        return;
      }

      if (inventory is! Inventory) {
        io.warn('Unexpected inventory type: ${inventory.runtimeType}');
        return;
      }

      _printInventory(inventory);
    } catch (e) {
      io.error('Failed to list hosts: $e');
      logger.error('Hosts error: $e');
    }
  }

  void _printInventory(Inventory inventory) {
    if (inventory.hosts.isEmpty) {
      io.warn('Inventory is empty (no hosts defined).');
      return;
    }

    io.section('Hosts (${inventory.hostCount})');
    for (final host in inventory.hosts) {
      final roleStr = host.roles.isNotEmpty
          ? ' [${host.roles.join(', ')}]'
          : '';
      final groupStr = host.groups.isNotEmpty
          ? ' (${host.groups.join(', ')})'
          : '';
      io.line('  $host$roleStr$groupStr');
      if (host.variables.isNotEmpty) {
        for (final entry in host.variables.entries) {
          io.line('    ${entry.key} = ${entry.value}');
        }
      }
    }

    if (inventory.roles.isNotEmpty) {
      io.section('Roles (${inventory.roleCount})');
      for (final role in inventory.roles) {
        io.line(
          '  ${role.name} (${role.hosts.length} host(s))'
          '${role.primary ? ' [primary]' : ''}'
          ' priority=${role.bootPriority}',
        );
        for (final host in role.hosts) {
          io.line('    - ${host.name} (${host.address})');
        }
      }
    }

    if (inventory.groups.isNotEmpty) {
      io.section('Groups (${inventory.groupCount})');
      for (final group in inventory.groups) {
        final hosts = inventory.getHostsByGroup(group);
        io.line('  $group (${hosts.length} host(s))');
        for (final host in hosts) {
          io.line('    - ${host.name} (${host.address})');
        }
      }
    }
  }
}
