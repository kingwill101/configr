import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should parse slurp block properties', () async {
    final blocks = await helper.processConfig('''
      slurp {
        src = "/tmp/data.txt"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('slurp'));
    expect(block.src, equals('/tmp/data.txt'));
  });

  test('should use default src value', () async {
    final blocks = await helper.processConfig('''
      slurp {}
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.src, isEmpty);
  });

  test('should fail when src is empty', () async {
    await helper.runConfig('''
      slurp {}
    ''');

    expect(helper.eventOfType<FailedEvent>(), isNotNull);
  });

  test('should fail when file does not exist', () async {
    await helper.runConfig('''
      slurp {
        src = "/nonexistent/file.txt"
      }
    ''');

    expect(helper.eventOfType<FailedEvent>(), isNotNull);
  });

  test('should read file and complete successfully', () async {
    const content = 'Hello, World!';
    await helper.createFile('/tmp/data.txt', content);

    final blocks = await helper.runConfig('''
      slurp {
        src = "/tmp/data.txt"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.status, equals('completed'));
  });

  test('should return correct dry-run summary', () async {
    final blocks = await helper.processConfig('''
      slurp {
        src = "/tmp/data.txt"
      }
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('slurp: /tmp/data.txt'));
  });

  test('should return empty dry-run summary', () async {
    final blocks = await helper.processConfig('''
      slurp {}
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('slurp: (empty)'));
  });
}
