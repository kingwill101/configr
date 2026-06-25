import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should parse group block properties', () async {
    final blocks = await helper.processConfig('''
      group {
        name = "mygroup"
        gid = "2001"
        system = true
        local = false
        force = true
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('group'));
    expect(block.name, equals('mygroup'));
    expect(block.gid, equals('2001'));
    expect(block.system, isTrue);
    expect(block.local, isFalse);
    expect(block.force, isTrue);
  });

  test('should use default values', () async {
    final blocks = await helper.processConfig('''
      group {
        name = "mygroup"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.name, equals('mygroup'));
    expect(block.gid, isEmpty);
    expect(block.system, isFalse);
    expect(block.local, isFalse);
    expect(block.force, isFalse);
  });

  test('should fail when name is missing', () async {
    await helper.runConfig('''
      group {
        gid = "2001"
      }
    ''');

    expect(helper.eventOfType<FailedEvent>(), isNotNull);
  });

  test('should return correct dry-run summary', () async {
    final blocks = await helper.processConfig('''
      group {
        name = "mygroup"
      }
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('group: mygroup (manage)'));
  });
}
