import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should decompress ZIP archive successfully', () async {
    // First create a ZIP archive, then decompress it
    const sourceDir = '/source';
    const archivePath = '/dest/archive.zip';
    const extractPath = '/extracted';

    await helper.createDir(sourceDir);
    await helper.createFile('$sourceDir/file1.txt', 'content1');
    await helper.createFile('$sourceDir/file2.txt', 'content2');
    await helper.createDir('$sourceDir/subdir');
    await helper.createFile('$sourceDir/subdir/file3.txt', 'content3');

    // Create ZIP archive
    await helper.runConfig('''
      compress {
        source = "$sourceDir"
        destination = "$archivePath"
        format = "zip"
        recursive = true
      }
    ''');

    // Now decompress
    await helper.runConfig('''
      decompress {
        source = "$archivePath"
        destination = "$extractPath"
        format = "zip"
      }
    ''');

    expect(await helper.fileExists('$extractPath/file1.txt'), isTrue);
    expect(await helper.fileExists('$extractPath/file2.txt'), isTrue);
    expect(await helper.readFile('$extractPath/file1.txt'), equals('content1'));
    expect(await helper.readFile('$extractPath/file2.txt'), equals('content2'));
  });

  test('should decompress TAR.GZ archive successfully', () async {
    const sourceDir = '/source_tar';
    const archivePath = '/dest/archive.tar.gz';
    const extractPath = '/extracted_tar';

    await helper.createDir(sourceDir);
    await helper.createFile('$sourceDir/file1.txt', 'content1');
    await helper.createFile('$sourceDir/file2.txt', 'content2');

    // Create TAR.GZ archive
    await helper.runConfig('''
      compress {
        source = "$sourceDir"
        destination = "$archivePath"
        format = "tar.gz"
        recursive = true
      }
    ''');

    // Now decompress
    await helper.runConfig('''
      decompress {
        source = "$archivePath"
        destination = "$extractPath"
        format = "tar.gz"
      }
    ''');

    expect(await helper.fileExists('$extractPath/file1.txt'), isTrue);
    expect(await helper.fileExists('$extractPath/file2.txt'), isTrue);
    expect(await helper.readFile('$extractPath/file1.txt'), equals('content1'));
    expect(await helper.readFile('$extractPath/file2.txt'), equals('content2'));
  });

  test('should flatten archive paths using archive path separators', () async {
    const sourceDir = '/source_flat';
    const archivePath = '/dest/flat.zip';
    const extractPath = '/flat';

    await helper.createDir('$sourceDir/subdir');
    await helper.createFile('$sourceDir/subdir/file.txt', 'flat content');

    await helper.runConfig('''
      compress {
        source = "$sourceDir"
        destination = "$archivePath"
        format = "zip"
        recursive = true
      }
    ''');

    await helper.runConfig('''
      decompress {
        source = "$archivePath"
        destination = "$extractPath"
        format = "zip"
        preserve_structure = false
      }
    ''');

    expect(await helper.fileExists('$extractPath/file.txt'), isTrue);
    expect(
      await helper.readFile('$extractPath/file.txt'),
      equals('flat content'),
    );
    expect(await helper.dirExists('$extractPath/subdir'), isFalse);
  });

  test('should fail when archive does not exist', () async {
    await helper.runConfig('''
      decompress {
        source = "/nonexistent/archive.zip"
        destination = "/extracted"
        format = "zip"
      }
    ''');

    // Destination directory should not have been created
    expect(await helper.dirExists('/extracted'), isFalse);
    // A FailedEvent should have been emitted
    expect(helper.emittedEvents.any((e) => e is FailedEvent), isTrue);
  });
}
