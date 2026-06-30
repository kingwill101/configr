import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should parse uri block properties', () async {
    final blocks = await helper.processConfig('''
      uri {
        url = "https://api.example.com/data"
        method = "POST"
        body = '{"key": "value"}'
        status_code = 201
        timeout = 60
        validate_certs = false
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('uri'));
    expect(block.url, equals('https://api.example.com/data'));
    expect(block.method, equals('POST'));
    expect(block.body, contains('key'));
    expect(block.statusCode, equals(201));
    expect(block.timeout, equals(60));
    expect(block.validateCerts, isFalse);
  });

  test('should use default values', () async {
    final blocks = await helper.processConfig('''
      uri {
        url = "https://example.com"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.url, equals('https://example.com'));
    expect(block.method, equals('GET'));
    expect(block.statusCode, equals(200));
    expect(block.timeout, equals(30));
    expect(block.validateCerts, isTrue);
  });

  test('should fail when url is missing', () async {
    await helper.runConfig('''
      uri {}
    ''');

    expect(helper.eventOfType<FailedEvent>(), isNotNull);
  });

  test('should return correct dry-run summary', () async {
    final blocks = await helper.processConfig('''
      uri {
        url = "https://api.example.com"
        method = "GET"
      }
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('uri: GET https://api.example.com'));
  });

  test('should return correct dry-run summary empty', () async {
    final blocks = await helper.processConfig('''
      uri {}
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('uri: (empty)'));
  });
}
