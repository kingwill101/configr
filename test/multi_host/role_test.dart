import 'package:test/test.dart';
import 'package:configr/src/multi_host/host.dart';
import 'package:configr/src/multi_host/role.dart';

void main() {
  group('Role', () {
    test('creates role with required name', () {
      final role = Role(name: 'web');

      expect(role.name, equals('web'));
      expect(role.hosts, isEmpty);
      expect(role.primary, isFalse);
      expect(role.bootPriority, equals(99));
      expect(role.bootGroupName, isNull);
      expect(role.hasHosts, isFalse);
      expect(role.hostCount, equals(0));
    });

    test('creates role with all properties', () {
      final hosts = [
        Host(name: 'web-01', address: '10.0.0.1'),
        Host(name: 'web-02', address: '10.0.0.2'),
      ];

      final role = Role(
        name: 'web',
        hosts: hosts,
        primary: true,
        bootPriority: 1,
        bootGroupName: 'frontend',
      );

      expect(role.name, equals('web'));
      expect(role.hosts, hasLength(2));
      expect(role.primary, isTrue);
      expect(role.bootPriority, equals(1));
      expect(role.bootGroupName, equals('frontend'));
      expect(role.hasHosts, isTrue);
      expect(role.hostCount, equals(2));
    });

    test('hasHosts returns false for empty role', () {
      final role = Role(name: 'worker');
      expect(role.hasHosts, isFalse);
      expect(role.hostCount, equals(0));
    });

    test('role equality is based on name', () {
      final role1 = Role(name: 'web', primary: true);
      final role2 = Role(name: 'web', primary: false);
      final role3 = Role(name: 'worker', primary: true);

      expect(role1, equals(role2));
      expect(role1, isNot(equals(role3)));
    });

    test('role hashCode is consistent with equality', () {
      final role1 = Role(name: 'web');
      final role2 = Role(name: 'web');
      expect(role1.hashCode, equals(role2.hashCode));
    });

    test('toString contains name and host count', () {
      final role = Role(
        name: 'web',
        hosts: [Host(name: 'web-01', address: '10.0.0.1')],
      );

      expect(role.toString(), contains('web'));
      expect(role.toString(), contains('1'));
    });

    test('boot priority defaults to 99', () {
      final role = Role(name: 'db');
      expect(role.bootPriority, equals(99));
    });

    test('primary defaults to false', () {
      final role = Role(name: 'worker');
      expect(role.primary, isFalse);
    });
  });
}
