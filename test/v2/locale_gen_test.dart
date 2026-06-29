import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should parse locale_gen block with single locale', () async {
    final blocks = await helper.processConfig('''
      locale_gen {
        name = "en_US.UTF-8"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('locale_gen'));
    expect(block.locales, equals(['en_US.UTF-8']));
  });

  test('should parse locale_gen block with list of locales', () async {
    final blocks = await helper.processConfig('''
      locale_gen {
        locales = "en_US.UTF-8, de_DE.UTF-8, fr_FR.UTF-8"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(
      block.locales,
      containsAll(['en_US.UTF-8', 'de_DE.UTF-8', 'fr_FR.UTF-8']),
    );
  });

  test('should use default value', () async {
    final blocks = await helper.processConfig('''
      locale_gen {}
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.locales, isEmpty);
  });

  test('should return correct dry-run summary', () async {
    final blocks = await helper.processConfig('''
      locale_gen {
        name = "ja_JP.UTF-8"
      }
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('locale_gen: ja_JP.UTF-8'));
  });

  test('should return empty dry-run summary when no locales', () async {
    final blocks = await helper.processConfig('''
      locale_gen {}
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), isEmpty);
  });
}
