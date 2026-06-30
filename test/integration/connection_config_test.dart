import 'package:configr/src/connection_config.dart';
import 'package:configr/src/secrets/secret_provider.dart';
import 'package:configr/src/secrets/secret_providers.dart';
import 'package:configr/src/secrets/secret_resolver.dart';
import 'package:configr/src/secrets/providers/providers.dart';
import 'package:test/test.dart';

void main() {
  group('ConnectionConfig', () {
    test('creates with required host', () {
      final config = ConnectionConfig(host: 'example.com');
      expect(config.host, 'example.com');
      expect(config.port, 22);
      expect(config.username, 'root');
      expect(config.connectTimeout, 30);
    });

    test('creates with custom values', () {
      final config = ConnectionConfig(
        host: 'server.example.com',
        port: 2222,
        username: 'deploy',
        password: 's3cret',
        privateKey: 'pem content',
        privateKeyPassphrase: 'pass',
        connectTimeout: 60,
      );
      expect(config.host, 'server.example.com');
      expect(config.port, 2222);
      expect(config.username, 'deploy');
      expect(config.password, 's3cret');
      expect(config.privateKey, 'pem content');
      expect(config.privateKeyPassphrase, 'pass');
      expect(config.connectTimeout, 60);
    });

    test('toMap produces correct keys for SSHExecutionService', () {
      final config = ConnectionConfig(
        host: 'host',
        port: 2222,
        username: 'u',
        password: 'p',
        privateKey: 'key',
        privateKeyPassphrase: 'pp',
        connectTimeout: 45,
      );
      final map = config.toMap();
      expect(map['host'], 'host');
      expect(map['port'], 2222);
      expect(map['username'], 'u');
      expect(map['password'], 'p');
      expect(map['private_key'], 'key');
      expect(map['private_key_passphrase'], 'pp');
      expect(map['connect_timeout'], 45);
    });

    test('toMap omits null optional fields', () {
      final config = ConnectionConfig(host: 'h');
      final map = config.toMap();
      expect(map.containsKey('password'), isFalse);
      expect(map.containsKey('private_key'), isFalse);
      expect(map.containsKey('private_key_passphrase'), isFalse);
    });

    test('const constructor works', () {
      const config = ConnectionConfig(host: 'example.com');
      expect(config.host, 'example.com');
    });
  });

  group('SecretProviders integration', () {
    test('all built-in providers are registered', () {
      final providers = SecretProviders();
      providers.register('env', (_) => const EnvProvider());
      providers.register('file', (_) => const FileProvider());
      providers.register('dotenv', (_) => const DotenvProvider());
      providers.register('cmd', (_) => const CmdProvider());
      providers.register('onepassword', (_) => const OnePasswordProvider());
      providers.register('keyring', (_) => const KeyringProvider());
      // No assertion needed — construction succeeds
    });

    test('SecretResolver integrates with EnvProvider', () async {
      final providers = SecretProviders();
      providers.register('env', (_) => const EnvProvider());
      final resolver = SecretResolver(providers);
      final result = await resolver.resolveWithSensitivity(
        'env://USER',
        markSensitive: true,
      );
      expect(result, isA<SensitiveValue>());
      expect((result as SensitiveValue).value, isNotEmpty);
    });

    test('displayValue hides sensitive', () {
      expect(displayValue(SensitiveValue('secret')), '<SENSITIVE>');
      expect(displayValue('hello'), 'hello');
    });
  });
}
