import 'package:test/test.dart';
import 'package:configr/src/multi_host/host.dart';
import 'package:configr/src/multi_host/role.dart';
import 'package:configr/src/multi_host/inventory.dart';
import 'package:configr/src/multi_host/target_resolver.dart';

void main() {
  group('TargetResolver', () {
    late Inventory inventory;
    late TargetResolver resolver;

    setUp(() {
      resolver = TargetResolver();

      final web01 = Host(name: 'web-01', address: '10.0.0.1', roles: ['web'], groups: ['production']);
      final web02 = Host(name: 'web-02', address: '10.0.0.2', roles: ['web'], groups: ['production']);
      final db01 = Host(name: 'db-01', address: '10.0.0.3', roles: ['db'], groups: ['production']);
      final worker01 = Host(name: 'worker-01', address: '10.0.0.4', roles: ['worker'], groups: ['staging']);

      inventory = Inventory.full(
        hosts: [web01, web02, db01, worker01],
        roles: [
          Role(name: 'web', hosts: [web01, web02]),
          Role(name: 'db', hosts: [db01]),
          Role(name: 'worker', hosts: [worker01]),
        ],
        groups: ['production', 'staging'],
        rolesByName: {
          'web': Role(name: 'web', hosts: [web01, web02]),
          'db': Role(name: 'db', hosts: [db01]),
          'worker': Role(name: 'worker', hosts: [worker01]),
        },
        hostsByGroup: {
          'production': ['web-01', 'web-02', 'db-01'],
          'staging': ['worker-01'],
        },
        hostsByName: {
          'web-01': web01,
          'web-02': web02,
          'db-01': db01,
          'worker-01': worker01,
        },
        defaultTargets: ['web-01', 'db-01'],
      );
    });

    group('resolve', () {
      test('returns hosts by explicit name', () {
        final hosts = resolver.resolve(
          hosts: ['web-01', 'db-01'],
          inventory: inventory,
        );

        expect(hosts, hasLength(2));
        expect(hosts.map((h) => h.name), containsAll(['web-01', 'db-01']));
      });

      test('returns hosts by role', () {
        final hosts = resolver.resolve(
          roles: ['web'],
          inventory: inventory,
        );

        expect(hosts, hasLength(2));
        expect(hosts.map((h) => h.name), containsAll(['web-01', 'web-02']));
      });

      test('returns hosts by group', () {
        final hosts = resolver.resolve(
          groups: ['staging'],
          inventory: inventory,
        );

        expect(hosts, hasLength(1));
        expect(hosts.first.name, equals('worker-01'));
      });

      test('returns default targets when no selection specified', () {
        final hosts = resolver.resolve(inventory: inventory);
        expect(hosts, hasLength(2));
        expect(hosts.map((h) => h.name), containsAll(['web-01', 'db-01']));
      });

      test('falls back to all hosts when no defaults', () {
        final emptyInventory = Inventory.full(
          hosts: inventory.hosts,
          roles: [],
          groups: [],
          rolesByName: {},
          hostsByGroup: {},
          hostsByName: inventory.hostsByName,
        );

        final hosts = resolver.resolve(inventory: emptyInventory);
        expect(hosts, hasLength(4));
      });

      test('returns empty when inventory is empty', () {
        final empty = Inventory();
        expect(resolver.resolve(inventory: empty), isEmpty);
      });

      test('explicit hosts overrides role selection', () {
        final hosts = resolver.resolve(
          hosts: ['web-01'],
          roles: ['worker'],
          inventory: inventory,
        );

        expect(hosts, hasLength(1));
        expect(hosts.first.name, equals('web-01'));
      });

      test('throws when throwIfNotFound and hosts missing', () {
        expect(
          () => resolver.resolve(
            hosts: ['nonexistent'],
            inventory: inventory,
            throwIfNotFound: true,
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('silently skips missing hosts when throwIfNotFound is false', () {
        final hosts = resolver.resolve(
          hosts: ['web-01', 'nonexistent'],
          inventory: inventory,
        );

        expect(hosts, hasLength(1));
        expect(hosts.first.name, equals('web-01'));
      });

      test('deduplicates hosts from multiple roles', () {
        inventory = Inventory.full(
          hosts: inventory.hosts,
          roles: [],
          groups: [],
          rolesByName: {
            'web': Role(name: 'web', hosts: [inventory.getHost('web-01')!]),
            'app': Role(name: 'app', hosts: [inventory.getHost('web-01')!]),
          },
          hostsByGroup: {},
          hostsByName: inventory.hostsByName,
        );

        final hosts = resolver.resolve(
          roles: ['web', 'app'],
          inventory: inventory,
        );

        expect(hosts, hasLength(1));
        expect(hosts.first.name, equals('web-01'));
      });
    });

    group('fromHost', () {
      test('creates target from host', () {
        final host = inventory.getHost('web-01')!;
        final target = resolver.fromHost(
          host: host,
          strategy: 'linear',
        );

        expect(target.host.name, equals('web-01'));
        expect(target.strategy, equals('linear'));
      });

      test('creates target with priority', () {
        final host = inventory.getHost('web-01')!;
        final target = resolver.fromHost(
          host: host,
          strategy: 'serial',
          priority: 5,
        );

        expect(target.priority, equals(5));
      });
    });

    group('fromHosts', () {
      test('creates targets from multiple hosts', () {
        final hosts = [inventory.getHost('web-01')!, inventory.getHost('web-02')!];
        final targets = resolver.fromHosts(hosts, 'linear');

        expect(targets, hasLength(2));
        expect(targets.every((t) => t.strategy == 'linear'), isTrue);
        expect(targets.map((t) => t.host.name), containsAll(['web-01', 'web-02']));
      });

      test('creates targets with shared priority', () {
        final hosts = [inventory.getHost('web-01')!, inventory.getHost('db-01')!];
        final targets = resolver.fromHosts(hosts, 'serial', priority: 1);

        expect(targets.every((t) => t.priority == 1), isTrue);
      });
    });
  });
}
