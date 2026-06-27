import 'package:test/test.dart';
import 'package:configr/src/multi_host/host.dart';
import 'package:configr/src/multi_host/role.dart';
import 'package:configr/src/multi_host/inventory.dart';

void main() {
  group('Inventory', () {
    final web01 = Host(name: 'web-01', address: '10.0.0.1', roles: ['web'], groups: ['production']);
    final web02 = Host(name: 'web-02', address: '10.0.0.2', roles: ['web'], groups: ['production']);
    final db01 = Host(name: 'db-01', address: '10.0.0.3', roles: ['db'], groups: ['production']);
    final worker01 = Host(name: 'worker-01', address: '10.0.0.4', roles: ['worker'], groups: ['staging']);

    final allHosts = [web01, web02, db01, worker01];

    final webRole = Role(name: 'web', hosts: [web01, web02], primary: true, bootPriority: 1);
    final dbRole = Role(name: 'db', hosts: [db01], bootPriority: 10);
    final workerRole = Role(name: 'worker', hosts: [worker01], bootPriority: 20);

    Inventory makeInventory({List<String>? defaultTargets}) {
      return Inventory.full(
        hosts: allHosts,
        roles: [webRole, dbRole, workerRole],
        groups: ['production', 'staging'],
        rolesByName: {
          'web': webRole,
          'db': dbRole,
          'worker': workerRole,
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
        metadata: {'version': '1.0'},
        defaultTargets: defaultTargets,
      );
    }

    test('creates empty inventory', () {
      final inventory = Inventory();
      expect(inventory.hosts, isEmpty);
      expect(inventory.roles, isEmpty);
      expect(inventory.groups, isEmpty);
      expect(inventory.hostCount, equals(0));
      expect(inventory.roleCount, equals(0));
      expect(inventory.groupCount, equals(0));
    });

    test('full inventory has correct counts', () {
      final inventory = makeInventory();
      expect(inventory.hostCount, equals(4));
      expect(inventory.roleCount, equals(3));
      expect(inventory.groupCount, equals(2));
    });

    test('getHost returns host by name', () {
      final inventory = makeInventory();
      final host = inventory.getHost('web-01');
      expect(host, isNotNull);
      expect(host!.address, equals('10.0.0.1'));
    });

    test('getHost returns null for unknown host', () {
      final inventory = makeInventory();
      expect(inventory.getHost('unknown'), isNull);
    });

    test('getHostsByRole returns all hosts for role', () {
      final inventory = makeInventory();
      final hosts = inventory.getHostsByRole('web');
      expect(hosts, hasLength(2));
      expect(hosts.map((h) => h.name), containsAll(['web-01', 'web-02']));
    });

    test('getHostsByRole returns empty for unknown role', () {
      final inventory = makeInventory();
      expect(inventory.getHostsByRole('unknown'), isEmpty);
    });

    test('getHostsByGroup returns all hosts in group', () {
      final inventory = makeInventory();
      final hosts = inventory.getHostsByGroup('production');
      expect(hosts, hasLength(3));
      expect(hosts.map((h) => h.name), containsAll(['web-01', 'web-02', 'db-01']));
    });

    test('getHostsByGroup returns empty for unknown group', () {
      final inventory = makeInventory();
      expect(inventory.getHostsByGroup('unknown'), isEmpty);
    });

    test('getAllHosts returns all hosts', () {
      final inventory = makeInventory();
      final hosts = inventory.getAllHosts();
      expect(hosts, hasLength(4));
    });

    test('getAllHosts returns unmodifiable list', () {
      final inventory = makeInventory();
      expect(() => inventory.getAllHosts() as dynamic..clear(), throwsUnsupportedError);
    });

    test('getRoleNames returns all role names', () {
      final inventory = makeInventory();
      expect(inventory.getRoleNames(), containsAll(['web', 'db', 'worker']));
    });

    test('getGroupNames returns all group names', () {
      final inventory = makeInventory();
      expect(inventory.getGroupNames(), containsAll(['production', 'staging']));
    });

    test('validate returns no errors for valid inventory', () {
      final inventory = makeInventory();
      expect(inventory.validate(), isEmpty);
    });

    test('validate detects duplicate host names', () {
      final duplicate = Host(name: 'web-01', address: '10.0.0.5');
      final inventory = Inventory(
        hosts: [web01, duplicate],
        hostsByName: {'web-01': web01},
      );
      final errors = inventory.validate();
      expect(errors, isNotEmpty);
      expect(errors.first, contains('Duplicate'));
    });

    test('defaultTargets is null when not set', () {
      final inventory = makeInventory();
      expect(inventory.defaultTargets, isNull);
    });

    test('defaultTargets is respected when set', () {
      final inventory = makeInventory(defaultTargets: ['web-01', 'web-02']);
      expect(inventory.defaultTargets, hasLength(2));
      expect(inventory.defaultTargets, containsAll(['web-01', 'web-02']));
    });

    test('toString shows counts', () {
      final inventory = makeInventory();
      expect(inventory.toString(), contains('4'));
      expect(inventory.toString(), contains('3'));
      expect(inventory.toString(), contains('2'));
    });
  });
}
