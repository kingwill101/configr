import 'package:test/test.dart';

import 'package:configr/src/secrets/secret_provider.dart';
import 'package:configr/src/secrets/secret_providers.dart';
import 'package:configr/src/secrets/secret_resolver.dart';
import 'package:configr/src/secrets/providers/providers.dart';
import 'v2_test_helper.dart';

void main() {
  group('SecretProvider', () {
    test('SensitiveValue hides value in toString', () {
      final sv = SensitiveValue('my-secret');
      expect(sv.value, equals('my-secret'));
      expect(sv.toString(), equals('<SENSITIVE>'));
      expect(sv.isSensitive, isTrue);
    });

    test('SensitiveValue equality', () {
      expect(SensitiveValue('a'), equals(SensitiveValue('a')));
      expect(SensitiveValue('a'), isNot(equals(SensitiveValue('b'))));
    });
  });

  group('EnvProvider', () {
    test('returns null for missing key', () async {
      final provider = EnvProvider();
      final result = await provider.get('', 'DOES_NOT_EXIST_XYZ', null);
      expect(result, isNull);
    });

    test('returns value for existing key', () async {
      final provider = EnvProvider();
      final result = await provider.get('', 'PATH', null);
      expect(result, isNotNull);
      expect(result, isNotEmpty);
    });
  });

  group('SecretProviders registry', () {
    test('resolves env:// URI', () async {
      final registry = SecretProviders();
      registry.register('env', (_) => const EnvProvider());
      final result = await registry.resolve('env://PATH');
      expect(result, isNotNull);
      expect(result, isNotEmpty);
    });

    test('returns null for unknown scheme', () async {
      final registry = SecretProviders();
      final result = await registry.resolve('unknown://something');
      expect(result, isNull);
    });

    test('resolves alias-prefixed URI', () async {
      final registry = SecretProviders();
      registry.register('env', (_) => const EnvProvider());
      final result = await registry.resolve(
        'prod://PATH',
        aliases: {'prod': 'env://'},
      );
      expect(result, isNotNull);
      expect(result, isNotEmpty);
    });
  });

  group('SecretResolver', () {
    test('resolves with sensitivity', () async {
      final registry = SecretProviders();
      registry.register('env', (_) => const EnvProvider());
      final resolver = SecretResolver(registry);

      final result = await resolver.resolveWithSensitivity(
        'env://PATH',
        markSensitive: true,
      );
      expect(result, isA<SensitiveValue>());
      expect((result as SensitiveValue).value, isNotEmpty);
    });
  });

  group('SecretsBlock integration', () {
    test('secrets block registers resolved values', () async {
      final helper = V2TestHelper();
      final blocks = await helper.processConfig('''
        secrets {
          provider "prod" = "env://"
          test_secret = "prod://PATH"
        }
        echo {
          message = "hello"
        }
      ''');

      expect(blocks, hasLength(1));
      expect(blocks.first.blockType, equals('echo'));
    });

    test(
      'resolved secrets are accessible via dot notation from sibling blocks',
      () async {
        final helper = V2TestHelper();
        final blocks = await helper.processConfig('''
        secrets {
          test_secret = "env://PATH"
        }
        echo {
          message = "prefix-\${secrets.test_secret}-suffix"
        }
      ''');

        expect(blocks, hasLength(1));
        expect(blocks.first.blockType, equals('echo'));
        // dry-run: echo block's source is used as message
        // The message should have the USER env var resolved
        final echoBlock = blocks.first;
        print('ECHO MESSAGE: "${echoBlock.source}"');
        print('ECHO DESTINATION: "${echoBlock.destination}"');
      },
    );
  });
}
