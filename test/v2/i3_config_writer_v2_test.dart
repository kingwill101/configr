import 'package:configr/src/writer/i3_config_writer_v2.dart';
import 'package:configr/src/blocks/action_block.dart';
import 'v2_test_helper.dart';
import 'package:test/test.dart';

/// Round-trip tests for [I3ConfigWriterV2].
void main() {
  late V2TestHelper helper;
  late I3ConfigWriterV2 writer;

  setUp(() {
    helper = V2TestHelper();
    writer = I3ConfigWriterV2();
  });

  group('I3ConfigWriterV2 round-trip', () {
    test('empty list produces empty string', () {
      final output = writer.writeBlocks([]);
      expect(output, isEmpty);
    });

    test('single copy block', () async {
      const input = '''
copy {
  source = "/src/file.txt"
  destination = "/dst/file.txt"
}
''';
      final blocks = await helper.processConfig(input);
      final output = writer.writeBlocks(blocks);
      expect(output, contains('copy {'));
      expect(output, contains('source = "/src/file.txt"'));
      expect(output, contains('destination = "/dst/file.txt"'));
    });

    test('copy block with all properties', () async {
      const input = '''
copy {
  source = "/src"
  destination = "/dst"
  recursive = true
  include = "*.dart"
  exclude = "*.log"
  conflict_resolution = "overwrite"
  show_progress = false
}
''';
      final blocks = await helper.processConfig(input);
      final output = writer.writeBlocks(blocks);
      expect(output, contains('copy {'));
      expect(output, contains('source = "/src"'));
      expect(output, contains('destination = "/dst"'));
      expect(output, contains('recursive = true'));
      expect(output, contains('include = "*.dart"'));
      expect(output, contains('exclude = "*.log"'));
      expect(output, contains('conflict_resolution = overwrite'));
      expect(output, contains('show_progress = false'));
    });

    test('echo block', () async {
      const input = '''
echo {
  message = "Hello World"
  level = "warning"
}
''';
      final blocks = await helper.processConfig(input);
      final output = writer.writeBlocks(blocks);
      expect(output, contains('echo {'));
      expect(output, contains('message = "Hello World"'));
      expect(output, contains('level = warning'));
    });

    test('file block with operations', () async {
      const input = '''
file {
  source = "/path/to/file"
  content = "file contents"
  operation = "edit"
  edit_mode = "append"
  backup_original = true
}
''';
      final blocks = await helper.processConfig(input);
      final output = writer.writeBlocks(blocks);
      expect(output, contains('file {'));
      expect(output, contains('content = "file contents"'));
      expect(output, contains('operation = edit'));
      expect(output, contains('edit_mode = append'));
      expect(output, contains('backup_original = true'));
    });

    test('multiple blocks of different types', () async {
      const input = '''
copy {
  source = "/src/a"
  destination = "/dst/a"
}
echo {
  message = "done"
}
symlink {
  source = "/src/b"
  destination = "/dst/b"
}
''';
      final blocks = await helper.processConfig(input);
      final output = writer.writeBlocks(blocks);
      expect(output, contains('copy {'));
      expect(output, contains('echo {'));
      expect(output, contains('symlink {'));
    });

    test('round-trip preserves block order', () async {
      const input = '''
echo {
  message = "First"
}
copy {
  source = "/src"
  destination = "/dst"
}
echo {
  message = "Last"
}
''';
      final blocks = await helper.processConfig(input);
      final output = writer.writeBlocks(blocks);

      // message = "First" gets quoted due to space
      // message = Last would be bare, but "First" has a space so it's quoted
      // Wait - "First" has no space, so it'll be bare "First" without quotes
      // Let's use positions of block type headers instead
      final firstEchoPos = output.indexOf('echo {');
      final copyPos = output.indexOf('copy {');
      final lastEchoPos = output.lastIndexOf('echo {');

      expect(firstEchoPos, greaterThanOrEqualTo(0));
      expect(
        copyPos,
        greaterThan(firstEchoPos),
        reason: 'copy block should come after first echo',
      );
      expect(
        lastEchoPos,
        greaterThan(copyPos),
        reason: 'second echo block should come after copy',
      );
    });

    test('symlink block', () async {
      const input = '''
symlink {
  source = "/src/target"
  destination = "/dst/link"
  conflict_resolution = "overwrite"
  validate_targets = false
}
''';
      final blocks = await helper.processConfig(input);
      final output = writer.writeBlocks(blocks);
      expect(output, contains('symlink {'));
      expect(output, contains('source = "/src/target"'));
      expect(output, contains('destination = "/dst/link"'));
      expect(output, contains('conflict_resolution = overwrite'));
      expect(output, contains('validate_targets = false'));
    });

    test('execute block', () async {
      const input = '''
execute {
  command = "echo hello"
  working_directory = "/tmp"
  timeout = 60
}
''';
      final blocks = await helper.processConfig(input);
      final output = writer.writeBlocks(blocks);
      expect(output, contains('execute {'));
      expect(output, contains('command = "echo hello"'));
      expect(output, contains('working_directory = "/tmp"'));
      expect(output, contains('timeout = 60'));
    });

    test('touch block', () async {
      const input = '''
touch {
  source = "/tmp/test.txt"
  create_if_missing = false
}
''';
      final blocks = await helper.processConfig(input);
      final output = writer.writeBlocks(blocks);
      expect(output, contains('touch {'));
      expect(output, contains('source = "/tmp/test.txt"'));
      expect(output, contains('create_if_missing = false'));
    });

    test('delete block', () async {
      const input = '''
delete {
  source = "/tmp/trash"
  recursive = true
  backup = true
  backup_path = "/tmp/backup"
  use_trash = false
}
''';
      final blocks = await helper.processConfig(input);
      final output = writer.writeBlocks(blocks);
      expect(output, contains('delete {'));
      expect(output, contains('recursive = true'));
      expect(output, contains('backup = true'));
      expect(output, contains('backup_path = "/tmp/backup"'));
    });
  });
}
