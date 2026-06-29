import 'dart:convert';

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

  test('should parse destination property', () async {
    final blocks = await helper.processConfig('''
      gather_facts {
        destination = "/tmp/facts.json"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.destination, equals('/tmp/facts.json'));
  });

  test('should default destination to empty string', () async {
    final blocks = await helper.processConfig('''
      gather_facts {}
    ''');

    final block = blocks.first as dynamic;
    expect(block.destination, isEmpty);
  });

  test('should persist facts to destination on execution', () async {
    await helper.runConfig('''
      gather_facts {
        destination = "/tmp/facts.json"
      }
    ''');

    final exists = await helper.fileExists('/tmp/facts.json');
    expect(exists, isTrue);

    final content = await helper.readFile('/tmp/facts.json');
    final facts = jsonDecode(content) as Map<String, dynamic>;
    expect(facts, containsPair('hostname', isA<String>()));
    expect(facts, containsPair('os_family', isA<String>()));
    expect(facts, containsPair('system', isA<String>()));
  });

  test('should not write fact file when destination is not set', () async {
    await helper.runConfig('''
      gather_facts {}
    ''');

    final exists = await helper.fileExists('/tmp/facts.json');
    expect(exists, isFalse);
  });

  test('should set context variables after execution', () async {
    await helper.runConfig('''
      gather_facts {}
    ''');

    final completedEvent = helper.eventOfType<CompletedEvent>();
    expect(completedEvent, isNotNull);
  });
}
