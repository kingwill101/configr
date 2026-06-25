import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should parse pause block with prompt', () async {
    final blocks = await helper.processConfig('''
      pause {
        prompt = "Press enter to continue"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('pause'));
    expect(block.prompt, equals('Press enter to continue'));
  });

  test('should parse seconds and minutes', () async {
    final blocks = await helper.processConfig('''
      pause {
        seconds = 5
        minutes = 2
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.seconds, equals(5));
    expect(block.minutes, equals(2));
    expect(block.prompt, isEmpty);
  });

  test('should use default values', () async {
    final blocks = await helper.processConfig('''
      pause {}
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.seconds, equals(0));
    expect(block.minutes, equals(0));
    expect(block.prompt, isEmpty);
  });

  test('should return correct dry-run summary with prompt', () async {
    final blocks = await helper.processConfig('''
      pause {
        prompt = "Continue?"
      }
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('pause: Continue?'));
  });

  test('should return correct dry-run summary empty', () async {
    final blocks = await helper.processConfig('''
      pause {}
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('pause: (waiting)'));
  });

  test('should complete successfully with zero seconds', () async {
    await helper.runConfig('''
      pause {}
    ''');

    final failedEvent = helper.eventOfType<FailedEvent>();
    expect(failedEvent, isNull);
  });
}
