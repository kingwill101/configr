import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should parse hostname block properties', () async {
    final blocks = await helper.processConfig('''
      hostname {
        name = "webserver01"
        use = "systemd"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('hostname'));
    expect(block.name, equals('webserver01'));
    expect(block.use, equals('systemd'));
  });

  test('should use default values', () async {
    final blocks = await helper.processConfig('''
      hostname {
        name = "webserver01"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.name, equals('webserver01'));
    expect(block.use, isEmpty);
  });

  test('should return correct dry-run summary', () async {
    final blocks = await helper.processConfig('''
      hostname {
        name = "myhost"
      }
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('hostname: myhost'));
  });

  test('should return empty dry-run summary when no name', () async {
    final blocks = await helper.processConfig('''
      hostname {}
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), isEmpty);
  });
}
