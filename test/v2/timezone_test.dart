import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should parse timezone block properties', () async {
    final blocks = await helper.processConfig('''
      timezone {
        timezone = "America/New_York"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('timezone'));
    expect(block.timezone, equals('America/New_York'));
  });

  test('should use default value', () async {
    final blocks = await helper.processConfig('''
      timezone {}
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.timezone, isEmpty);
  });

  test('should return correct dry-run summary', () async {
    final blocks = await helper.processConfig('''
      timezone {
        timezone = "Europe/London"
      }
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('timezone: Europe/London'));
  });

  test('should return empty dry-run summary when no timezone', () async {
    final blocks = await helper.processConfig('''
      timezone {}
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), isEmpty);
  });
}
