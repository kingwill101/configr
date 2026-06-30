import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should parse script block properties', () async {
    final blocks = await helper.processConfig('''
      script {
        script = "/path/to/script.sh"
        args = "--verbose"
        chdir = "/tmp"
        creates = "/tmp/.done"
        removes = "/tmp/flag"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('script'));
    expect(block.script, equals('/path/to/script.sh'));
    expect(block.args, equals('--verbose'));
    expect(block.chdir, equals('/tmp'));
    expect(block.creates, equals('/tmp/.done'));
    expect(block.removes, equals('/tmp/flag'));
  });

  test('should use default values', () async {
    final blocks = await helper.processConfig('''
      script {
        script = "/path/to/script.sh"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.script, equals('/path/to/script.sh'));
    expect(block.args, isEmpty);
    expect(block.chdir, isEmpty);
    expect(block.creates, isEmpty);
    expect(block.removes, isEmpty);
  });

  test('should fail when script is missing', () async {
    await helper.runConfig('''
      script {}
    ''');

    expect(helper.eventOfType<FailedEvent>(), isNotNull);
  });

  test('should skip when creates path exists', () async {
    await helper.createFile('/tmp/.done', '');

    final blocks = await helper.runConfig('''
      script {
        script = "/path/to/script.sh"
        creates = "/tmp/.done"
      }
    ''');

    expect(blocks, hasLength(1));
    expect(helper.eventOfType<StatusUpdateEvent>(), isNotNull);
  });

  test('should skip when removes path does not exist', () async {
    final blocks = await helper.runConfig('''
      script {
        script = "/path/to/script.sh"
        removes = "/tmp/nonexistent"
      }
    ''');

    expect(blocks, hasLength(1));
    expect(helper.eventOfType<StatusUpdateEvent>(), isNotNull);
  });

  test('should return correct dry-run summary', () async {
    final blocks = await helper.processConfig('''
      script {
        script = "/path/to/script.sh"
        args = "--force"
      }
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('script: /path/to/script.sh --force'));
  });

  test('should return correct dry-run summary empty', () async {
    final blocks = await helper.processConfig('''
      script {}
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('script: (empty)'));
  });
}
