import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should parse alternatives block properties', () async {
    final blocks = await helper.processConfig('''
      alternatives {
        name = "java"
        path = "/usr/lib/jvm/java-17-openjdk/bin/java"
        link = "/usr/bin/java"
        priority = 1701
        state = "selected"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('alternatives'));
    expect(block.name, equals('java'));
    expect(block.path, equals('/usr/lib/jvm/java-17-openjdk/bin/java'));
    expect(block.link, equals('/usr/bin/java'));
    expect(block.priority, equals(1701));
    expect(block.linkState, equals('selected'));
  });

  test('should use default values', () async {
    final blocks = await helper.processConfig('''
      alternatives {
        name = "editor"
        path = "/usr/bin/vim.basic"
        link = "/usr/bin/editor"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.name, equals('editor'));
    expect(block.priority, equals(50));
    expect(block.linkState, equals('selected'));
    expect(block.subcommands, isEmpty);
  });

  test('should fail when name is missing', () async {
    await helper.runConfig('''
      alternatives {
        path = "/usr/bin/java"
        link = "/usr/bin/java"
      }
    ''');

    expect(helper.eventOfType<FailedEvent>(), isNotNull);
  });

  test('should return correct dry-run summary', () async {
    final blocks = await helper.processConfig('''
      alternatives {
        name = "java"
        path = "/usr/bin/java"
      }
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('alternatives: java -> /usr/bin/java (selected)'));
  });

  test('should return minimal dry-run summary', () async {
    final blocks = await helper.processConfig('''
      alternatives {}
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), isEmpty);
  });
}
