import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  group('JSON Format Validation', () {
    test('should validate JSON format successfully', () async {
      const filePath = '/test/valid.json';
      await helper.createFile(filePath, '{"name": "test", "value": 123}');

      // Should not throw
      await helper.runConfig('''
        validate {
          source = "$filePath"
          format = "json"
        }
      ''');
    });

    test('should fail on invalid JSON format', () async {
      const filePath = '/test/invalid.json';
      await helper.createFile(filePath, '{invalid json}');

      await helper.runConfig('''
        validate {
          source = "$filePath"
          format = "json"
        }
      ''');

      // The block ran but encountered a format error
      expect(helper.emittedEvents.any((e) => e is CompletedEvent), isFalse);
    });
  });

  group('YAML Format Validation', () {
    test('should validate YAML format successfully', () async {
      const filePath = '/test/valid.yaml';
      await helper.createFile(filePath, 'name: test\nvalue: 123\n');

      // Should not throw
      await helper.runConfig('''
        validate {
          source = "$filePath"
          format = "yaml"
        }
      ''');
    });

    test('should fail on empty YAML file', () async {
      const filePath = '/test/empty.yaml';
      await helper.createFile(filePath, '');

      await helper.runConfig('''
        validate {
          source = "$filePath"
          format = "yaml"
        }
      ''');

      // The block ran but encountered a format error
      expect(helper.emittedEvents.any((e) => e is CompletedEvent), isFalse);
    });
  });

  group('Checksum Validation', () {
    test('should validate checksum successfully', () async {
      const filePath = '/test/file.txt';
      const content = 'test content for checksum';
      // Pre-compute expected sha256
      final expectedChecksum =
          'c8ce4e97a404b12b1d8f0e245f04ff607be1048b16d973c2f23bab86655c808b';
      await helper.createFile(filePath, content);

      // Should complete without throwing
      await helper.runConfig('''
        validate {
          source = "$filePath"
          checksum = "$expectedChecksum"
        }
      ''');
    });

    test('should fail on checksum mismatch', () async {
      const filePath = '/test/file.txt';
      await helper.createFile(filePath, 'different content');

      await helper.runConfig('''
        validate {
          source = "$filePath"
          checksum = "0000000000000000000000000000000000000000"
        }
      ''');

      // The block ran but checksum didn't match — no CompletedEvent emitted
      expect(helper.emittedEvents.any((e) => e is CompletedEvent), isFalse);
    });
  });
}
