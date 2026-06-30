import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should parse raw block properties', () async {
    final blocks = await helper.processConfig('''
      raw {
        command = "echo"
        args = "hello world"
        chdir = "/tmp"
        stdin = "input data"
        executable = "/bin/bash"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('raw'));
    expect(block.command, equals('echo'));
    expect(block.args, equals('hello world'));
    expect(block.chdir, equals('/tmp'));
    expect(block.stdin, equals('input data'));
    expect(block.executable, equals('/bin/bash'));
  });

  test('should use default values', () async {
    final blocks = await helper.processConfig('''
      raw {
        command = "ls"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.command, equals('ls'));
    expect(block.args, isEmpty);
    expect(block.chdir, isEmpty);
    expect(block.executable, equals('/bin/sh'));
  });

  test('should fail when command is missing', () async {
    await helper.runConfig('''
      raw {}
    ''');

    expect(helper.eventOfType<FailedEvent>(), isNotNull);
  });

  test('should return correct dry-run summary', () async {
    final blocks = await helper.processConfig('''
      raw {
        command = "echo"
        args = "hello"
      }
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('raw: echo hello'));
  });

  test('should return correct dry-run summary empty', () async {
    final blocks = await helper.processConfig('''
      raw {}
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('raw: (empty)'));
  });
}
