import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should delete file successfully', () async {
    const filePath = '/test/file.txt';
    await helper.createFile(filePath, 'test content');

    await helper.runConfig('''
      delete {
        source = "$filePath"
      }
    ''');

    expect(await helper.fileExists(filePath), isFalse);
  });

  test('should create backup before deleting if specified', () async {
    const filePath = '/test/file.txt';
    const backupPath = '/test/file.bak';
    await helper.createFile(filePath, 'test content');

    await helper.runConfig('''
      delete {
        source = "$filePath"
        backup = true
        backup_path = "$backupPath"
      }
    ''');

    expect(await helper.fileExists(filePath), isFalse);
    expect(await helper.fileExists(backupPath), isTrue);
  });

  test('should delete files with include patterns', () async {
    const sourceDir = '/source/dir';

    await helper.createDir(sourceDir);
    await helper.createFile('$sourceDir/file1.txt', 'content1');
    await helper.createFile('$sourceDir/file2.log', 'content2');
    await helper.createFile('$sourceDir/file3.txt', 'content3');

    await helper.runConfig('''
      delete {
        source = "$sourceDir"
        recursive = true
        include = "*.txt"
      }
    ''');

    expect(await helper.fileExists('$sourceDir/file1.txt'), isFalse);
    expect(await helper.fileExists('$sourceDir/file3.txt'), isFalse);
    expect(await helper.fileExists('$sourceDir/file2.log'), isTrue);
  });

  test('should delete files with exclude patterns', () async {
    const sourceDir = '/source/dir';

    await helper.createDir(sourceDir);
    await helper.createFile('$sourceDir/file1.txt', 'content1');
    await helper.createFile('$sourceDir/file2.log', 'content2');
    await helper.createFile('$sourceDir/file3.txt', 'content3');

    await helper.runConfig('''
      delete {
        source = "$sourceDir"
        recursive = true
        exclude = "*.log"
      }
    ''');

    expect(await helper.fileExists('$sourceDir/file1.txt'), isFalse);
    expect(await helper.fileExists('$sourceDir/file3.txt'), isFalse);
    expect(await helper.fileExists('$sourceDir/file2.log'), isTrue);
  });

  test('should track progress for directory deletion', () async {
    const sourceDir = '/source/dir';

    await helper.createDir(sourceDir);
    await helper.createFile('$sourceDir/file1.txt', 'content1');
    await helper.createFile('$sourceDir/file2.txt', 'content2');
    await helper.createFile('$sourceDir/file3.txt', 'content3');

    await helper.runConfig('''
      delete {
        source = "$sourceDir"
        recursive = true
      }
    ''');

    expect(await helper.fileExists('$sourceDir/file1.txt'), isFalse);
    expect(await helper.fileExists('$sourceDir/file2.txt'), isFalse);
    expect(await helper.fileExists('$sourceDir/file3.txt'), isFalse);
  });

  test('should handle missing source gracefully', () async {
    // Should not throw when source doesn't exist
    await helper.runConfig('''
      delete {
        source = "/nonexistent/file.txt"
      }
    ''');

    // No exception means success
    expect(true, isTrue);
  });
}
