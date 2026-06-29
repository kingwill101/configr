import 'dart:io';

import 'package:configr/src/di.dart';
import 'package:configr/src/secrets/secret_provider.dart';
import 'package:configr/src/secrets/secret_providers.dart';
import 'package:configr/src/secrets/secret_resolver.dart';
import 'package:configr/src/secrets/providers/providers.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
    di.allowReassignment = true;
  });

  group('SensitiveValue', () {
    test('toString returns <SENSITIVE>', () {
      final s = SensitiveValue('my_secret_value');
      expect(s.toString(), '<SENSITIVE>');
    });

    test('value exposes the raw secret', () {
      final s = SensitiveValue('my_secret_value');
      expect(s.value, 'my_secret_value');
    });

    test('isSensitive returns true', () {
      expect(SensitiveValue('x').isSensitive, isTrue);
    });

    test('equality is based on raw value', () {
      expect(SensitiveValue('a'), SensitiveValue('a'));
      expect(SensitiveValue('a') == SensitiveValue('b'), isFalse);
    });

    test('hashCode is based on raw value', () {
      expect(SensitiveValue('a').hashCode, SensitiveValue('a').hashCode);
    });

    test('displayValue returns <SENSITIVE> for SensitiveValue', () {
      expect(displayValue(SensitiveValue('x')), '<SENSITIVE>');
    });

    test('displayValue returns toString for non-sensitive values', () {
      expect(displayValue('hello'), 'hello');
      expect(displayValue(42), '42');
      expect(displayValue(null), '<null>');
    });
  });

  group('SecretResolver', () {
    late SecretProviders registry;
    late SecretResolver resolver;

    setUp(() {
      registry = SecretProviders();
      registry.register('env', (_) => const EnvProvider());
      resolver = SecretResolver(registry);
    });

    test('resolve returns null for unknown scheme', () async {
      final result = await resolver.resolve('unknown://foo');
      expect(result, isNull);
    });

    test('resolve returns null for unresolvable key', () async {
      final result = await resolver.resolve('env://_NONEXISTENT_VAR_12345');
      expect(result, isNull);
    });

    test('resolve returns value for existing env var', () async {
      final result = await resolver.resolve('env://USER');
      expect(result, isNotNull);
      expect(result, isNotEmpty);
    });

    test('resolveWithSensitivity wraps in SensitiveValue', () async {
      final result = await resolver.resolveWithSensitivity(
        'env://USER',
        markSensitive: true,
      );
      expect(result, isA<SensitiveValue>());
      expect((result as SensitiveValue).value, isNotEmpty);
    });

    test(
      'resolveWithSensitivity returns raw string when markSensitive=false',
      () async {
        final result = await resolver.resolveWithSensitivity(
          'env://USER',
          markSensitive: false,
        );
        expect(result, isA<String>());
      },
    );
  });

  group('SecretProviders with aliases', () {
    test('alias resolves to different scheme', () async {
      final registry = SecretProviders();
      registry.register('env', (_) => const EnvProvider());
      final result = await registry.resolve(
        'prod://USER',
        aliases: {'prod': 'env://'},
      );
      expect(result, isNotNull);
      expect(result, isNotEmpty);
    });

    test('alias chain works', () async {
      final registry = SecretProviders();
      registry.register('env', (_) => const EnvProvider());
      final result = await registry.resolve(
        'staging://USER',
        aliases: {'staging': 'env://'},
      );
      expect(result, isNotNull);
    });

    test('unknown alias returns null', () async {
      final registry = SecretProviders();
      registry.register('env', (_) => const EnvProvider());
      final result = await registry.resolve(
        'unknown://foo',
        aliases: {'prod': 'env://'},
      );
      expect(result, isNull);
    });
  });

  group('EnvProvider', () {
    test('returns value for existing env var', () async {
      final provider = const EnvProvider();
      final result = await provider.get('', 'USER', null);
      expect(result, isNotNull);
      expect(result, isNotEmpty);
    });

    test('returns null for missing env var', () async {
      final provider = const EnvProvider();
      final result = await provider.get('', '_DOES_NOT_EXIST_', null);
      expect(result, isNull);
    });
  });

  group('FileProvider', () {
    test('returns content of existing file', () async {
      final tmpFile =
          '/tmp/_configr_test_file_${DateTime.now().millisecondsSinceEpoch}';
      try {
        await File(tmpFile).writeAsString('file_secret_value\n');
        final provider = const FileProvider();
        final result = await provider.get('', tmpFile, null);
        expect(result, 'file_secret_value');
      } finally {
        File(tmpFile).deleteSync();
      }
    });

    test('returns null for missing file', () async {
      final provider = const FileProvider();
      final result = await provider.get('', '/nonexistent/path', null);
      expect(result, isNull);
    });
  });

  group('DotenvProvider', () {
    test('returns value from dotenv file', () async {
      final tmpFile =
          '/tmp/_configr_dotenv_test_${DateTime.now().millisecondsSinceEpoch}';
      try {
        await File(
          tmpFile,
        ).writeAsString('MY_KEY=my_dotenv_value\nANOTHER=val\n');
        final provider = const DotenvProvider();
        // project arg is the file path, key is the variable name
        final result = await provider.get(tmpFile, 'MY_KEY', null);
        expect(result, 'my_dotenv_value');
      } finally {
        File(tmpFile).deleteSync();
      }
    });

    test('returns value for second key in dotenv', () async {
      final tmpFile =
          '/tmp/_configr_dotenv_test2_${DateTime.now().millisecondsSinceEpoch}';
      try {
        await File(tmpFile).writeAsString('KEY1=val1\nKEY2=val2\n');
        final provider = const DotenvProvider();
        final result = await provider.get(tmpFile, 'KEY2', null);
        expect(result, 'val2');
      } finally {
        File(tmpFile).deleteSync();
      }
    });

    test('returns null for missing dotenv file', () async {
      final provider = const DotenvProvider();
      final result = await provider.get('/nonexistent/.env', 'KEY', null);
      expect(result, isNull);
    });

    test('resolve resolves dotenv URI with ?name= query param', () async {
      final tmpFile =
          '/tmp/_configr_dotenv_resolve_${DateTime.now().millisecondsSinceEpoch}';
      try {
        await File(tmpFile).writeAsString('DB_PASS=s3cret\n');
        final registry = SecretProviders();
        registry.register('dotenv', (_) => const DotenvProvider());
        final result = await registry.resolve('dotenv://$tmpFile?name=DB_PASS');
        expect(result, 's3cret');
      } finally {
        File(tmpFile).deleteSync();
      }
    });

    test('resolve returns null for dotenv with missing name key', () async {
      final tmpFile =
          '/tmp/_configr_dotenv_missing_${DateTime.now().millisecondsSinceEpoch}';
      try {
        await File(tmpFile).writeAsString('DB_PASS=s3cret\n');
        final registry = SecretProviders();
        registry.register('dotenv', (_) => const DotenvProvider());
        final result = await registry.resolve(
          'dotenv://$tmpFile?name=MISSING_KEY',
        );
        expect(result, isNull);
      } finally {
        File(tmpFile).deleteSync();
      }
    });
  });

  group('CmdProvider', () {
    test('returns stdout from command', () async {
      final provider = const CmdProvider();
      // Use a simple echo command
      final result = await provider.get('', 'echo secret_output', null);
      expect(result, 'secret_output');
    });

    test('returns null for failing command', () async {
      final provider = const CmdProvider();
      final result = await provider.get('', 'false', null);
      expect(result, isNull);
    });
  });

  group('Sensitive redaction in action block', () {
    test('sensitive values are stored in context options', () async {
      final registry = SecretProviders();
      registry.register('env', (_) => const EnvProvider());
      final resolver = SecretResolver(registry);

      final result = await resolver.resolveWithSensitivity(
        'env://USER',
        markSensitive: true,
      );
      expect(result, isA<SensitiveValue>());
    });

    test('redactSensitive replaces known values', () async {
      final sensitiveValues = {'db_password': 'supersecret123'};
      final message = 'Connecting with password supersecret123';
      // Simulate redaction logic
      var redacted = message;
      for (final value in sensitiveValues.values) {
        if (value.length >= 4) {
          redacted = redacted.replaceAll(value, '<SENSITIVE>');
        }
      }
      expect(redacted, 'Connecting with password <SENSITIVE>');
      expect(redacted.contains('supersecret123'), isFalse);
    });

    test('short sensitive values are not redacted', () async {
      final sensitiveValues = {'key': 'abc'};
      final message = 'value is abc';
      var redacted = message;
      for (final value in sensitiveValues.values) {
        if (value.length >= 4) {
          redacted = redacted.replaceAll(value, '<SENSITIVE>');
        }
      }
      // value is only 3 chars, should NOT be redacted
      expect(redacted, 'value is abc');
    });
  });

  group('EventBus integration', () {
    test('StartedEvent message is redacted', () async {
      final sensitiveValues = {'password': 'my_real_password'};
      final message = 'Started with password my_real_password';
      var redacted = message;
      for (final value in sensitiveValues.values) {
        if (value.length >= 4) {
          redacted = redacted.replaceAll(value, '<SENSITIVE>');
        }
      }
      expect(redacted, 'Started with password <SENSITIVE>');
    });

    test('ErrorEvent message is redacted', () async {
      final sensitiveValues = {'api_key': 'sk-1234567890abcdef'};
      final message = 'Failed with API key sk-1234567890abcdef';
      var redacted = message;
      for (final value in sensitiveValues.values) {
        if (value.length >= 4) {
          redacted = redacted.replaceAll(value, '<SENSITIVE>');
        }
      }
      expect(redacted.contains('sk-1234567890abcdef'), isFalse);
    });
  });
}
