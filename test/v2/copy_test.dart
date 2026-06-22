import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should copy file successfully', () async {
    const sourceFile = '/source/dir/file1.txt';
    const destFile = '/dest/dir/file1.txt';
    const content = 'content1';

    await helper.createDir('/source/dir');
    await helper.createFile(sourceFile, content);

    await helper.runConfig('''
      copy {
        source = "$sourceFile"
        destination = "$destFile"
      }
    ''');

    expect(await helper.fileExists(destFile), isTrue);
    expect(await helper.readFile(destFile), equals(content));
  });

  test('should handle directory copy with recursive', () async {
    const sourceDir = '/source/dir';
    const destDir = '/dest/dir';

    await helper.createDir(sourceDir);
    await helper.createFile('$sourceDir/file1.txt', 'content1');
    await helper.createFile('$sourceDir/file2.txt', 'content2');

    await helper.runConfig('''
      copy {
        source = "$sourceDir"
        destination = "$destDir"
        recursive = true
      }
    ''');

    expect(await helper.dirExists(destDir), isTrue);
    expect(await helper.readFile('$destDir/file1.txt'), equals('content1'));
    expect(await helper.readFile('$destDir/file2.txt'), equals('content2'));
  });

  test('should handle rollback correctly', () async {
    const sourceFile = '/source/dir/file1.txt';
    const destFile = '/dest/dir/file1.txt';

    await helper.createDir('/source/dir');
    await helper.createFile(sourceFile, 'content1');

    await helper.runConfigWithRollback('''
      copy {
        source = "$sourceFile"
        destination = "$destFile"
      }
    ''');

    expect(await helper.fileExists(destFile), isFalse);
  });

  test('should fail when source does not exist', () async {
    await helper.runConfig('''
      copy {
        source = "/nonexistent/file.txt"
        destination = "/dest/file.txt"
      }
    ''');

    // Target file should not have been created
    expect(await helper.fileExists('/dest/file.txt'), isFalse);
    // A FailedEvent should have been emitted
    expect(helper.emittedEvents.any((e) => e is FailedEvent), isTrue);
  });

  test('should copy files with include patterns', () async {
    const sourceDir = '/source/dir';
    const destDir = '/dest/dir';

    await helper.createDir(sourceDir);
    await helper.createFile('$sourceDir/file1.txt', 'content1');
    await helper.createFile('$sourceDir/file2.log', 'content2');
    await helper.createFile('$sourceDir/file3.txt', 'content3');

    await helper.runConfig('''
      copy {
        source = "$sourceDir"
        destination = "$destDir"
        recursive = true
        include = "*.txt"
      }
    ''');

    expect(await helper.fileExists('$destDir/file1.txt'), isTrue);
    expect(await helper.fileExists('$destDir/file3.txt'), isTrue);
    expect(await helper.fileExists('$destDir/file2.log'), isFalse);
  });

  test('should copy files with exclude patterns', () async {
    const sourceDir = '/source/dir';
    const destDir = '/dest/dir';

    await helper.createDir(sourceDir);
    await helper.createFile('$sourceDir/file1.txt', 'content1');
    await helper.createFile('$sourceDir/file2.log', 'content2');
    await helper.createFile('$sourceDir/file3.txt', 'content3');

    await helper.runConfig('''
      copy {
        source = "$sourceDir"
        destination = "$destDir"
        recursive = true
        exclude = "*.log"
      }
    ''');

    expect(await helper.fileExists('$destDir/file1.txt'), isTrue);
    expect(await helper.fileExists('$destDir/file3.txt'), isTrue);
    expect(await helper.fileExists('$destDir/file2.log'), isFalse);
  });

  test('should handle conflict resolution - skip', () async {
    const sourceFile = '/source/file.txt';
    const destFile = '/dest/file.txt';

    await helper.createDir('/source');
    await helper.createDir('/dest');
    await helper.createFile(sourceFile, 'new content');
    await helper.createFile(destFile, 'existing content');

    final blocks = await helper.runConfig('''
      copy {
        source = "$sourceFile"
        destination = "$destFile"
        conflict_resolution = "skip"
      }
    ''');

    expect(await helper.readFile(destFile), equals('existing content'));
    final block = blocks.first;
    expect((block as dynamic).copiedFiles, equals(0));
    expect((block as dynamic).skippedFiles, equals(1));
  });

  test('should handle conflict resolution - overwrite', () async {
    const sourceFile = '/source/file.txt';
    const destFile = '/dest/file.txt';

    await helper.createDir('/source');
    await helper.createDir('/dest');
    await helper.createFile(sourceFile, 'new content');
    await helper.createFile(destFile, 'existing content');

    final blocks = await helper.runConfig('''
      copy {
        source = "$sourceFile"
        destination = "$destFile"
        conflict_resolution = "overwrite"
      }
    ''');

    expect(await helper.readFile(destFile), equals('new content'));
    final block = blocks.first;
    expect((block as dynamic).copiedFiles, equals(1));
    expect((block as dynamic).overwrittenFiles, equals(1));
  });
}
