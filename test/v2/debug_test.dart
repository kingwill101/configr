import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should parse debug block with msg property', () async {
    final blocks = await helper.processConfig('''
      resources {
        debug {
          msg = "Hello Debug"
        }
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('debug'));
    expect(block.msg, equals('Hello Debug'));
  });

  test('should parse debug block with var property', () async {
    final blocks = await helper.processConfig('''
      resources {
        debug {
          var = "some_variable"
        }
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('debug'));
    expect(block.varName, equals('some_variable'));
  });

  test('should emit started event during execution', () async {
    helper.clearEvents();

    await helper.runConfig('''
      resources {
        debug {
          msg = "Test message"
        }
      }
    ''');

    final startedEvent = helper.eventOfType<StartedEvent>();
    expect(startedEvent, isNotNull);
    expect(startedEvent!.message, equals('debug'));
  });

  test('should return correct dry-run summary with msg', () async {
    final blocks = await helper.processConfig('''
      resources {
        debug {
          msg = "Debug message"
        }
      }
    ''');

    final block = blocks.first as dynamic;
    final summary = block.dryRunSummary();
    expect(summary, equals('debug: Debug message'));
  });

  test('should return correct dry-run summary with var', () async {
    final blocks = await helper.processConfig('''
      resources {
        debug {
          var = "my_var"
        }
      }
    ''');

    final block = blocks.first as dynamic;
    final summary = block.dryRunSummary();
    expect(summary, equals('debug: var=my_var'));
  });

  test('should return empty summary when no properties', () async {
    final blocks = await helper.processConfig('''
      resources {
        debug {}
      }
    ''');

    final block = blocks.first as dynamic;
    final summary = block.dryRunSummary();
    expect(summary, equals('debug: (empty)'));
  });
}
