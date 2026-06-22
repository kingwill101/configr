import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should backup file to specified location', () async {
    const sourcePath = '/source/test.txt';
    const backupPath = '/backups/test.bak';
    const content = 'test content';

    await helper.createDir('/source');
    await helper.createFile(sourcePath, content);

    await helper.runConfig('''
      backup {
        source = "$sourcePath"
        destination = "$backupPath"
      }
    ''');

    expect(await helper.fileExists(backupPath), isTrue);
    expect(await helper.readFile(backupPath), equals(content));
  });

  test('should backup directory recursively', () async {
    const sourceDir = '/source/dir';
    const backupDir = '/backups/dir';

    await helper.createDir(sourceDir);
    await helper.createFile('$sourceDir/file1.txt', 'content1');
    await helper.createFile('$sourceDir/file2.txt', 'content2');

    await helper.runConfig('''
      backup {
        source = "$sourceDir"
        destination = "$backupDir"
        recursive = true
      }
    ''');

    expect(await helper.dirExists(backupDir), isTrue);
    expect(await helper.readFile('$backupDir/file1.txt'), equals('content1'));
    expect(await helper.readFile('$backupDir/file2.txt'), equals('content2'));
  });

  test('should rollback by deleting backup', () async {
    const sourcePath = '/source/test.txt';
    const backupPath = '/backups/test.bak';
    const content = 'test content';

    await helper.createDir('/source');
    await helper.createFile(sourcePath, content);

    await helper.runConfigWithRollback('''
      backup {
        source = "$sourcePath"
        destination = "$backupPath"
      }
    ''');

    expect(await helper.fileExists(backupPath), isFalse);
  });

  test('should fail when source does not exist', () async {
    await helper.runConfig('''
        backup {
          source = "/nonexistent/test.txt"
          destination = "/backups/test.bak"
        }
      ''');

    // Backup should not have been created
    expect(await helper.fileExists('/backups/test.bak'), isFalse);
    // A FailedEvent should have been emitted
    expect(helper.emittedEvents.any((e) => e is FailedEvent), isTrue);
  });
}
