import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should parse set_fact block with assignment properties', () async {
    final blocks = await helper.runConfig('''
      set_fact {
        foo = "bar"
        number = 42
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('set_fact'));
    expect(block.id, isNotEmpty);
  });

  test('should emit started and status events', () async {
    helper.clearEvents();
    
    await helper.runConfig('''
      set_fact {
        test_var = "test_value"
      }
    ''');

    final startedEvent = helper.eventOfType<StartedEvent>();
    expect(startedEvent, isNotNull);
    expect(startedEvent!.message, contains('Setting facts'));

    final statusEvent = helper.eventOfType<StatusUpdateEvent>();
    expect(statusEvent, isNotNull);
    expect(statusEvent!.message, contains('fact'));
  });

  test('should return correct dry-run summary', () async {
    final blocks = await helper.processConfig('''
      set_fact {
        key1 = "value1"
        key2 = "value2"
      }
    ''');

    final block = blocks.first as dynamic;
    final summary = block.dryRunSummary();
    expect(summary, equals('set_fact: 2 fact(s)'));
  });

  test('should return empty summary when no facts', () async {
    final blocks = await helper.processConfig('''
      set_fact {}
    ''');

    final block = blocks.first as dynamic;
    final summary = block.dryRunSummary();
    expect(summary, equals('set_fact: (empty)'));
  });
}