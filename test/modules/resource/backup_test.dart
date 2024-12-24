import 'package:configr/exceptions.dart';
import 'package:test/test.dart';
import 'package:configr/modules/resource/backup.dart';
import 'package:configr/models/file_model.dart';
import 'package:configr/models/action.dart';
import '../../helpers/test_helper.dart';

void main() {
  late TestHelper helper;

  setUp(() {
    helper = TestHelper();
  });

  test('should backup file to specified location', () async {
    // Arrange
    const sourcePath = 'source/test.txt';
    const backupPath = 'backups/test.bak';
    const content = 'test content';

    await helper.createTestFile(sourcePath, content);

    final resourceModel = ResourceModel(
        source: sourcePath,
        destination: sourcePath, // Same as source since we're backing up
        actions: [
          Action(type: 'backup', properties: {'backup_path': backupPath})
        ]);

    final module = FileBackupModule(resourceModel, resourceModel.actions.first,
        fileSystem: helper.fileSystem);

    // Act
    await module();

    // Assert
    expect(await helper.fileExists(backupPath), isTrue);
    await helper.verifyFileContent(backupPath, content);
  });

  test('should backup directory recursively', () async {
    // Arrange
    const sourceDir = 'source/dir';
    const backupDir = 'backups/dir';

    await helper.createDirectory(sourceDir);
    await helper.createTestFile('$sourceDir/file1.txt', 'content1');
    await helper.createTestFile('$sourceDir/file2.txt', 'content2');

    final resourceModel = ResourceModel(
        source: sourceDir,
        destination: sourceDir,
        type: ResourceType.directory,
        actions: [
          Action(
              type: 'backup',
              properties: {'backup_path': backupDir, 'recursive': 'true'})
        ]);

    final module = FileBackupModule(resourceModel, resourceModel.actions.first,
        fileSystem: helper.fileSystem);

    // Act
    await module();

    // Assert
    expect(await helper.directoryExists(backupDir), isTrue);
    await helper.verifyFileContent('$backupDir/file1.txt', 'content1');
    await helper.verifyFileContent('$backupDir/file2.txt', 'content2');
  });

  test('should rollback by deleting backup', () async {
    // Arrange
    const sourcePath = 'source/test.txt';
    const backupPath = 'backups/test.bak';
    const content = 'test content';

    await helper.createTestFile(sourcePath, content);

    final resourceModel =
        ResourceModel(source: sourcePath, destination: sourcePath, actions: [
      Action(type: 'backup', properties: {'backup_path': backupPath})
    ]);

    final module = FileBackupModule(resourceModel, resourceModel.actions.first,
        fileSystem: helper.fileSystem);

    // Act
    await module();
    await module.rollback();

    // Assert
    expect(await helper.fileExists(backupPath), isFalse);
  });

  test('should handle missing source gracefully', () async {
    // Arrange
    const sourcePath = 'nonexistent/test.txt';
    const backupPath = 'backups/test.bak';

    final resourceModel =
        ResourceModel(source: sourcePath, destination: sourcePath, actions: [
      Action(type: 'backup', properties: {'backup_path': backupPath})
    ]);

    final module = FileBackupModule(resourceModel, resourceModel.actions.first,
        fileSystem: helper.fileSystem);

    // Act & Assert
    expect(() => module(), throwsA(isA<SourceNotFoundException>()));
  });
}
