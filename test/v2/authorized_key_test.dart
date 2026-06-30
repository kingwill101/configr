import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should parse authorized_key block properties', () async {
    final blocks = await helper.processConfig('''
      authorized_key {
        user = "john"
        key = "ssh-ed25519 AAAAC3... john@test"
        key_options = "no-port-forwarding"
        path = "/home/john/.ssh/authorized_keys"
        manage_dir = false
        exclusive = true
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('authorized_key'));
    expect(block.user, equals('john'));
    expect(block.key, contains('ssh-ed25519'));
    expect(block.keyOptions, equals('no-port-forwarding'));
    expect(block.path, equals('/home/john/.ssh/authorized_keys'));
    expect(block.manageDir, isFalse);
    expect(block.exclusive, isTrue);
  });

  test('should use default values', () async {
    final blocks = await helper.processConfig('''
      authorized_key {
        user = "john"
        key = "ssh-ed25519 AAAA..."
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.user, equals('john'));
    expect(block.manageDir, isTrue);
    expect(block.exclusive, isFalse);
    expect(block.path, isEmpty);
  });

  test('should fail when user is missing', () async {
    await helper.runConfig('''
      authorized_key {
        key = "ssh-ed25519 AAAA..."
      }
    ''');

    expect(helper.eventOfType<FailedEvent>(), isNotNull);
  });

  test('should fail when key is missing', () async {
    await helper.runConfig('''
      authorized_key {
        user = "john"
      }
    ''');

    expect(helper.eventOfType<FailedEvent>(), isNotNull);
  });

  test('should return correct dry-run summary', () async {
    final blocks = await helper.processConfig('''
      authorized_key {
        user = "john"
        key = "ssh-ed25519 AAAA..."
      }
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('authorized_key: john'));
  });

  test('should return correct dry-run summary empty', () async {
    final blocks = await helper.processConfig('''
      authorized_key {}
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('authorized_key: (empty)'));
  });
}
