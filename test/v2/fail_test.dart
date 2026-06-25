import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should parse fail block with message', () async {
    final blocks = await helper.processConfig('''
      fail {
        msg = "Something went wrong"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('fail'));
    expect(block.msg, equals('Something went wrong'));
  });

  test('should use default message', () async {
    final blocks = await helper.processConfig('''
      fail {}
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.msg, equals('Assertion failed'));
  });

  test('should always fail with FailedEvent', () async {
    await helper.runConfig('''
      fail {
        msg = "custom error"
      }
    ''');

    final failedEvent = helper.eventOfType<FailedEvent>();
    expect(failedEvent, isNotNull);
    expect(failedEvent!.message, contains('custom error'));
  });

  test('should return correct dry-run summary', () async {
    final blocks = await helper.processConfig('''
      fail {
        msg = "error message"
      }
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('fail: error message'));
  });
}
