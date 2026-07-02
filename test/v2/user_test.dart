@TestOn('linux')
library;

import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should parse user block properties', () async {
    final blocks = await helper.processConfig('''
      user {
        name = "john"
        uid = "1001"
        group = "staff"
        groups = "wheel,docker"
        comment = "John Doe"
        home = "/home/john"
        shell = "/bin/zsh"
        password = "encrypted-pass"
        system = false
        create_home = true
        move_home = false
        remove = false
        force = false
        append = true
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('user'));
    expect(block.name, equals('john'));
    expect(block.uid, equals('1001'));
    expect(block.group, equals('staff'));
    expect(block.groups, equals('wheel,docker'));
    expect(block.comment, equals('John Doe'));
    expect(block.home, equals('/home/john'));
    expect(block.shell, equals('/bin/zsh'));
    expect(block.password, equals('encrypted-pass'));
    expect(block.system, isFalse);
    expect(block.createHome, isTrue);
    expect(block.moveHome, isFalse);
    expect(block.remove, isFalse);
    expect(block.force, isFalse);
    expect(block.append, isTrue);
  });

  test('should use default values', () async {
    final blocks = await helper.processConfig('''
      user {
        name = "john"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.name, equals('john'));
    expect(block.uid, isEmpty);
    expect(block.system, isFalse);
    expect(block.createHome, isTrue);
    expect(block.moveHome, isFalse);
    expect(block.append, isFalse);
  });

  test('should fail when name is missing', () async {
    await helper.runConfig('''
      user {
        uid = "1001"
      }
    ''');

    expect(helper.eventOfType<FailedEvent>(), isNotNull);
  });

  test('should return correct dry-run summary', () async {
    final blocks = await helper.processConfig('''
      user {
        name = "john"
      }
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('user: john (manage)'));
  });
}
