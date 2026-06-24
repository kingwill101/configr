import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should parse gather_facts block properties', () async {
    final blocks = await helper.processConfig('''
      gather_facts {
        gather_subset = "all"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('gather_facts'));
    expect(block.gatherSubset, equals('all'));
  });

  test('should use default gather_subset value', () async {
    final blocks = await helper.processConfig('''
      gather_facts {}
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('gather_facts'));
    expect(block.gatherSubset, equals('all'));
  });

  test('should emit started event during execution', () async {
    helper.clearEvents();
    
    await helper.runConfig('''
      gather_facts {}
    ''');

    final startedEvent = helper.eventOfType<StartedEvent>();
    expect(startedEvent, isNotNull);
    expect(startedEvent!.message, contains('Gathering facts'));
  });
}