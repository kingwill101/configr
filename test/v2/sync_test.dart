import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should initialize with default values', () async {
    await helper.createDir('/source');
    await helper.createDir('/dest');

    final blocks = await helper.runConfig('''
      sync {
        source = "/source"
        destination = "/dest"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first;
    expect(block.blockType, equals('sync'));
    expect((block as dynamic).syncMode, equals('bidirectional'));
    expect((block as dynamic).conflictResolution, equals('newer'));
    expect((block as dynamic).preservePermissions, isTrue);
    expect((block as dynamic).preserveTimestamps, isTrue);
    expect((block as dynamic).deleteOrphans, isFalse);
  });

  test('should load configuration from properties', () async {
    await helper.createDir('/source');
    await helper.createDir('/dest');

    final blocks = await helper.runConfig('''
      sync {
        source = "/source"
        destination = "/dest"
        mode = "source_to_dest"
        conflict_resolution = "source"
        preserve_permissions = false
        preserve_timestamps = false
        delete_orphans = true
      }
    ''');

    final block = blocks.first;
    expect((block as dynamic).syncMode, equals('source_to_dest'));
    expect((block as dynamic).conflictResolution, equals('source'));
    expect((block as dynamic).preservePermissions, isFalse);
    expect((block as dynamic).preserveTimestamps, isFalse);
    expect((block as dynamic).deleteOrphans, isTrue);
  });

  test('should sync nested files using target filesystem paths', () async {
    await helper.createDir('/source/sub');
    await helper.createFile('/source/sub/file.txt', 'nested content');

    await helper.runConfig('''
      sync {
        source = "/source"
        destination = "/dest"
        mode = "source_to_dest"
        preserve_timestamps = false
      }
    ''');

    expect(await helper.fileExists('/dest/sub/file.txt'), isTrue);
    expect(
      await helper.readFile('/dest/sub/file.txt'),
      equals('nested content'),
    );
  });
}
