import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should create symlink successfully', () async {
    const sourcePath = '/source/test.txt';
    const linkPath = '/dest/link.txt';

    await helper.createDir('/source');
    await helper.createFile(sourcePath, 'test content');

    await helper.runConfig('''
      symlink {
        source = "$sourcePath"
        destination = "$linkPath"
      }
    ''');

    final link = helper.fileSystem.link(linkPath);
    expect(await link.exists(), isTrue);
    expect(await link.target(), equals(sourcePath));
  });

  test('should create destination directory if needed', () async {
    const sourcePath = '/source/test.txt';
    const linkPath = '/dest/subdir/link.txt';

    await helper.createDir('/source');
    await helper.createFile(sourcePath, 'test content');

    await helper.runConfig('''
      symlink {
        source = "$sourcePath"
        destination = "$linkPath"
      }
    ''');

    final link = helper.fileSystem.link(linkPath);
    expect(await link.exists(), isTrue);
  });

  test('should fail when source does not exist', () async {
    const sourcePath = '/nonexistent/source.txt';
    const linkPath = '/dest/link.txt';

    await helper.runConfig('''
      symlink {
        source = "$sourcePath"
        destination = "$linkPath"
      }
    ''');

    // Symlink should not have been created
    final link = helper.fileSystem.link(linkPath);
    expect(await link.exists(), isFalse);
    // A FailedEvent should have been emitted
    expect(helper.emittedEvents.any((e) => e is FailedEvent), isTrue);
  });

  test('should skip existing symlink when configured', () async {
    const sourcePath = '/source/test.txt';
    const linkPath = '/dest/link.txt';

    await helper.createDir('/source');
    await helper.createFile(sourcePath, 'test content');
    await helper.createFile('/source/other.txt', 'other content');

    // Create first symlink
    await helper.runConfig('''
      symlink {
        source = "$sourcePath"
        destination = "$linkPath"
      }
    ''');

    // Try to create second symlink with skip conflict resolution
    await helper.runConfig('''
      symlink {
        source = "/source/other.txt"
        destination = "$linkPath"
        conflict_resolution = "skip"
      }
    ''');

    final link = helper.fileSystem.link(linkPath);
    expect(await link.exists(), isTrue);
    expect(await link.target(), equals(sourcePath));
  });

  test('should overwrite existing symlink when configured', () async {
    const sourcePath = '/source/test.txt';
    const linkPath = '/dest/link.txt';

    await helper.createDir('/source');
    await helper.createFile(sourcePath, 'test content');
    await helper.createFile('/source/other.txt', 'other content');

    // Create first symlink
    await helper.runConfig('''
      symlink {
        source = "$sourcePath"
        destination = "$linkPath"
      }
    ''');

    // Overwrite with second
    await helper.runConfig('''
      symlink {
        source = "/source/other.txt"
        destination = "$linkPath"
        conflict_resolution = "overwrite"
      }
    ''');

    final link = helper.fileSystem.link(linkPath);
    expect(await link.exists(), isTrue);
    expect(await link.target(), equals('/source/other.txt'));
  });

  test('should create bulk symlinks using target filesystem paths', () async {
    await helper.createDir('/source/sub');
    await helper.createFile('/source/sub/file.txt', 'test content');

    await helper.runConfig('''
      symlink {
        source = "/source"
        destination = "/dest"
      }
    ''');

    final link = helper.fileSystem.link('/dest/sub/file.txt');
    expect(await link.exists(), isTrue);
    expect(await link.target(), equals('/source/sub/file.txt'));
  });

  test('should handle rollback correctly', () async {
    const sourcePath = '/source/test.txt';
    const linkPath = '/dest/link.txt';

    await helper.createDir('/source');
    await helper.createFile(sourcePath, 'test content');

    await helper.runConfigWithRollback('''
      symlink {
        source = "$sourcePath"
        destination = "$linkPath"
      }
    ''');

    expect(await helper.fileExists(linkPath), isFalse);
  });
}
