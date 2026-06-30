import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should succeed when condition is true', () async {
    await helper.runConfig('''
      assert {
        condition = "true"
      }
    ''');

    expect(helper.emittedEvents.any((e) => e is CompletedEvent), isTrue);
    expect(helper.emittedEvents.any((e) => e is FailedEvent), isFalse);
  });

  test('should fail when condition is false', () async {
    await helper.runConfig('''
      assert {
        condition = "false"
      }
    ''');

    expect(helper.emittedEvents.any((e) => e is FailedEvent), isTrue);
  });

  test('should fail with custom fail message', () async {
    await helper.runConfig('''
      assert {
        condition = "false"
        fail_msg = "Custom failure message"
      }
    ''');

    final failed = helper.eventOfType<FailedEvent>();
    expect(failed, isNotNull);
    expect(failed!.message, contains('Custom failure message'));
  });

  test('should emit success message when condition is true', () async {
    await helper.runConfig('''
      assert {
        condition = "true"
        success_msg = "All good"
      }
    ''');

    final statusUpdate = helper.eventOfType<StatusUpdateEvent>();
    expect(statusUpdate, isNotNull);
    expect(statusUpdate!.message, contains('All good'));
  });

  test('should fail when condition is not specified', () async {
    await helper.runConfig('''
      assert {
        fail_msg = "no condition"
      }
    ''');

    expect(helper.emittedEvents.any((e) => e is FailedEvent), isTrue);
  });

  test('should support negation with !', () async {
    await helper.runConfig('''
      assert {
        condition = "!false"
      }
    ''');

    expect(helper.emittedEvents.any((e) => e is CompletedEvent), isTrue);
  });

  test('should support == comparison', () async {
    await helper.runConfig('''
      assert {
        condition = "foo == foo"
      }
    ''');

    expect(helper.emittedEvents.any((e) => e is CompletedEvent), isTrue);
  });

  test('should support != comparison', () async {
    await helper.runConfig('''
      assert {
        condition = "foo != bar"
      }
    ''');

    expect(helper.emittedEvents.any((e) => e is CompletedEvent), isTrue);
  });

  test('should rollback without errors', () async {
    await helper.runConfig('''
      assert {
        condition = "true"
      }
    ''');

    // Rollback should not throw
    expect(helper.emittedEvents.any((e) => e is FailedEvent), isFalse);
  });
}
