import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should compress directory with ZIP format', () async {
    const sourceDir = '/source';
    const destPath = '/dest/archive.zip';

    await helper.createDir(sourceDir);
    await helper.createFile('$sourceDir/file1.txt', 'content1');
    await helper.createFile('$sourceDir/file2.txt', 'content2');

    await helper.runConfig('''
      compress {
        source = "$sourceDir"
        destination = "$destPath"
        format = "zip"
        recursive = true
      }
    ''');

    final archive = helper.fileSystem.file(destPath);
    expect(await archive.exists(), isTrue);
    expect(await archive.length(), greaterThan(0));
  });

  test('should compress directory with TAR.GZ format', () async {
    const sourceDir = '/source_tar';
    const destPath = '/dest/archive.tar.gz';

    await helper.createDir(sourceDir);
    await helper.createFile('$sourceDir/file1.txt', 'content1');
    await helper.createFile('$sourceDir/file2.txt', 'content2');

    await helper.runConfig('''
      compress {
        source = "$sourceDir"
        destination = "$destPath"
        format = "tar.gz"
        recursive = true
      }
    ''');

    final archive = helper.fileSystem.file(destPath);
    expect(await archive.exists(), isTrue);
    expect(await archive.length(), greaterThan(0));
  });

  test('should compress single file with GZ format', () async {
    const sourcePath = '/source_file.txt';
    const destPath = '/dest/archive.gz';

    await helper.createFile(sourcePath, 'test content for compression');

    await helper.runConfig('''
      compress {
        source = "$sourcePath"
        destination = "$destPath"
        format = "gz"
      }
    ''');

    final archive = helper.fileSystem.file(destPath);
    expect(await archive.exists(), isTrue);
    expect(await archive.length(), greaterThan(0));
  });

  test('should fail when source does not exist', () async {
    await helper.runConfig('''
      compress {
        source = "/nonexistent"
        destination = "/dest/archive.zip"
        format = "zip"
      }
    ''');

    // Archive should not have been created
    expect(await helper.fileExists('/dest/archive.zip'), isFalse);
    // A FailedEvent should have been emitted
    expect(helper.emittedEvents.any((e) => e is FailedEvent), isTrue);
  });
}
