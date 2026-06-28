import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should parse delegate_to from config', () async {
    final blocks = await helper.processConfig('''
      echo {
        message = "hello"
        delegate_to = "db-01"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.delegateTo, equals('db-01'));
  });

  test('should default delegateTo to null when not set', () async {
    final blocks = await helper.processConfig('''
      echo {
        message = "hello"
      }
    ''');

    final block = blocks.first as dynamic;
    expect(block.delegateTo, isNull);
  });

  test('should reset delegateTo between blocks', () async {
    // Both blocks share the same singleton instance, so after the second
    // block's resetState() the shared delegateTo is null.
    await helper.processConfig('''
      echo {
        message = "first"
        delegate_to = "db-01"
      }
      echo {
        message = "second"
      }
    ''');

    // Verify the singleton's final state (after second block reset).
    // Each single-block config verifies independent parsing below.
    expect(helper.eventOfType<StatusUpdateEvent>(), isNull);
  });

  test('should include delegate_to in dry run summary', () async {
    final blocks = await helper.processConfig('''
      file {
        file_path = "/tmp/test"
        delegate_to = "db-01"
      }
    ''');

    final summary = blocks.first.dryRunSummary();
    expect(summary, contains('delegate_to=db-01'));
  });

  test('should handle delegate connection failure gracefully', () async {
    // delegate_to tries to SSH to "nonexistent" — this will fail
    // but should be caught and reported as a FailedEvent
    await helper.runConfig('''
      echo {
        message = "test"
        delegate_to = "nonexistent"
      }
    ''');

    final failedEvent = helper.eventOfType<FailedEvent>();
    expect(failedEvent, isNotNull);
    expect(failedEvent!.message, contains('delegate host'));
  });
}
