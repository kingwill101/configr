import 'package:test/test.dart';
import 'package:i3config/i3config_v2.dart' as i3;
import 'package:configr/src/multi_host/inventory_block.dart';
import 'package:configr/src/multi_host/inventory.dart';

/// Helper to set up an i3context and process an inventory block.
Future<Inventory?> processInventory(String configBody) async {
  final config = i3.Config.parse('''
inventory {
  $configBody
}
''');

  final processor = i3.ConfigProcessor();
  processor.registerBlockHandler(InventoryBlock());

  final context = processor.context;
  await processor.process(config);

  return context.globalContext.options['_inventory'] as Inventory?;
}

void main() {
  group('InventoryBlock', () {
    test('parses empty inventory', () async {
      final inventory = await processInventory('');
      expect(inventory, isNotNull);
      expect(inventory!.hosts, isEmpty);
    });

    test('parses single host', () async {
      final inventory = await processInventory('''
        host "web-01" {
          address = "10.0.0.1"
          roles = ["web"]
          groups = ["production"]
        }
      ''');

      expect(inventory, isNotNull);
      expect(inventory!.hostCount, equals(1));
      expect(inventory.getHost('web-01'), isNotNull);
      expect(inventory.getHost('web-01')!.address, equals('10.0.0.1'));
      expect(inventory.getHost('web-01')!.roles, contains('web'));
      expect(inventory.getHost('web-01')!.groups, contains('production'));
    });

    test('parses multiple hosts', () async {
      final inventory = await processInventory('''
        host "web-01" {
          address = "10.0.0.1"
          roles = ["web"]
        }
        host "web-02" {
          address = "10.0.0.2"
          roles = ["web"]
        }
        host "db-01" {
          address = "10.0.0.3"
          roles = ["db"]
        }
      ''');

      expect(inventory, isNotNull);
      expect(inventory!.hostCount, equals(3));
      expect(inventory.getHost('web-01'), isNotNull);
      expect(inventory.getHost('web-02'), isNotNull);
      expect(inventory.getHost('db-01'), isNotNull);
    });

    test('builds role mappings from host roles', () async {
      final inventory = await processInventory('''
        host "web-01" {
          address = "10.0.0.1"
          roles = ["web", "app"]
        }
        host "web-02" {
          address = "10.0.0.2"
          roles = ["web"]
        }
      ''');

      expect(inventory, isNotNull);
      final webHosts = inventory!.getHostsByRole('web');
      expect(webHosts, hasLength(2));

      final appHosts = inventory.getHostsByRole('app');
      expect(appHosts, hasLength(1));
    });

    test('builds group mappings from host groups', () async {
      final inventory = await processInventory('''
        host "web-01" {
          address = "10.0.0.1"
          groups = ["production"]
        }
        host "db-01" {
          address = "10.0.0.2"
          groups = ["production"]
        }
        host "worker-01" {
          address = "10.0.0.3"
          groups = ["staging"]
        }
      ''');

      expect(inventory, isNotNull);
      expect(inventory!.getHostsByGroup('production'), hasLength(2));
      expect(inventory.getHostsByGroup('staging'), hasLength(1));
    });

    test('parses default_targets', () async {
      final inventory = await processInventory('''
        default_targets = ["web-01", "db-01"]
        host "web-01" { address = "10.0.0.1" }
        host "db-01" { address = "10.0.0.2" }
      ''');

      expect(inventory, isNotNull);
      expect(inventory!.defaultTargets, containsAll(['web-01', 'db-01']));
    });

    test('handles optional username and port', () async {
      final inventory = await processInventory('''
        host "web-01" {
          address = "10.0.0.1"
          username = "admin"
          port = 2222
        }
      ''');

      expect(inventory, isNotNull);
      final host = inventory!.getHost('web-01')!;
      expect(host.username, equals('admin'));
      expect(host.port, equals(2222));
    });

    test('uses defaults for optional fields', () async {
      final inventory = await processInventory('''
        host "web-01" { address = "10.0.0.1" }
      ''');

      expect(inventory, isNotNull);
      final host = inventory!.getHost('web-01')!;
      expect(host.port, equals(22));
      expect(host.username, equals('root'));
      expect(host.privateKey, isNull);
    });
  });
}
