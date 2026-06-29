import 'package:test/test.dart';
import 'package:configr/src/multi_host/host.dart';

void main() {
  group('Host', () {
    test('creates host with required fields', () {
      final host = Host(name: 'web-01', address: '10.0.0.1');

      expect(host.name, equals('web-01'));
      expect(host.address, equals('10.0.0.1'));
      expect(host.port, equals(22));
      expect(host.username, equals('root'));
      expect(host.privateKey, isNull);
      expect(host.variables, isEmpty);
      expect(host.roles, isEmpty);
      expect(host.groups, isEmpty);
    });

    test('creates host with all optional fields', () {
      final host = Host(
        name: 'db-master',
        address: 'db.example.com',
        port: 2222,
        username: 'admin',
        privateKey: '/home/admin/.ssh/id_rsa',
        privateKeyPassphrase: 'secret',
        connectTimeout: 30,
        variables: {'ansible_os_family': 'Debian'},
        roles: ['database', 'primary'],
        groups: ['production'],
        connectionConfig: {
          'hostKeyAlgorithms': ['ssh-rsa'],
        },
      );

      expect(host.name, equals('db-master'));
      expect(host.address, equals('db.example.com'));
      expect(host.port, equals(2222));
      expect(host.username, equals('admin'));
      expect(host.privateKey, equals('/home/admin/.ssh/id_rsa'));
      expect(host.privateKeyPassphrase, equals('secret'));
      expect(host.connectTimeout, equals(30));
      expect(host.variables, containsPair('ansible_os_family', 'Debian'));
      expect(host.roles, containsAll(['database', 'primary']));
      expect(host.groups, contains('production'));
      expect(host.connectionConfig, isNotEmpty);
    });

    test('isRole returns true when host has role', () {
      final host = Host(
        name: 'web-01',
        address: '10.0.0.1',
        roles: ['web', 'app'],
      );

      expect(host.isRole('web'), isTrue);
      expect(host.isRole('app'), isTrue);
      expect(host.isRole('worker'), isFalse);
    });

    test('isGroup returns true when host belongs to group', () {
      final host = Host(
        name: 'web-01',
        address: '10.0.0.1',
        groups: ['production', 'eu-central'],
      );

      expect(host.isGroup('production'), isTrue);
      expect(host.isGroup('eu-central'), isTrue);
      expect(host.isGroup('staging'), isFalse);
    });

    test('host equality is based on name', () {
      final host1 = Host(name: 'web-01', address: '10.0.0.1');
      final host2 = Host(name: 'web-01', address: '10.0.0.2');
      final host3 = Host(name: 'web-02', address: '10.0.0.1');

      expect(host1, equals(host2));
      expect(host1, isNot(equals(host3)));
    });

    test('host hashCode is consistent with equality', () {
      final host1 = Host(name: 'web-01', address: '10.0.0.1');
      final host2 = Host(name: 'web-01', address: '10.0.0.2');

      expect(host1.hashCode, equals(host2.hashCode));
    });

    test('toString contains name and address', () {
      final host = Host(name: 'web-01', address: '10.0.0.1');

      expect(host.toString(), contains('web-01'));
      expect(host.toString(), contains('10.0.0.1'));
    });

    test('hosts can be used in a Set', () {
      final hosts = <Host>{
        Host(name: 'web-01', address: '10.0.0.1'),
        Host(name: 'web-01', address: '10.0.0.2'),
        Host(name: 'web-02', address: '10.0.0.1'),
      };

      expect(hosts.length, equals(2));
    });

    group('toConnectionMap', () {
      test('returns required fields', () {
        final host = Host(name: 'web-01', address: '10.0.0.1');
        final map = host.toConnectionMap();

        expect(map['host'], equals('10.0.0.1'));
        expect(map['port'], equals(22));
        expect(map['username'], equals('root'));
      });

      test('includes private key when set', () {
        final host = Host(
          name: 'web-01',
          address: '10.0.0.1',
          privateKey: '/home/admin/.ssh/id_rsa',
        );
        final map = host.toConnectionMap();

        expect(map['private_key'], equals('/home/admin/.ssh/id_rsa'));
      });

      test('includes private key passphrase when set', () {
        final host = Host(
          name: 'web-01',
          address: '10.0.0.1',
          privateKeyPassphrase: 'secret',
        );
        final map = host.toConnectionMap();

        expect(map['private_key_passphrase'], equals('secret'));
      });

      test('includes connect timeout when set', () {
        final host = Host(
          name: 'web-01',
          address: '10.0.0.1',
          connectTimeout: 30,
        );
        final map = host.toConnectionMap();

        expect(map['connect_timeout'], equals(30));
      });

      test('omits optional fields when not set', () {
        final host = Host(name: 'web-01', address: '10.0.0.1');
        final map = host.toConnectionMap();

        expect(map.containsKey('private_key'), isFalse);
        expect(map.containsKey('private_key_passphrase'), isFalse);
        expect(map.containsKey('connect_timeout'), isFalse);
      });

      test('uses custom port and username', () {
        final host = Host(
          name: 'db-01',
          address: '10.0.0.5',
          port: 2222,
          username: 'admin',
        );
        final map = host.toConnectionMap();

        expect(map['port'], equals(2222));
        expect(map['username'], equals('admin'));
      });
    });
  });
}
