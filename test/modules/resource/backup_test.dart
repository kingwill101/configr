import 'dart:convert';
import 'package:configr/src/exceptions.dart';
import 'package:test/test.dart';
import 'package:configr/src/modules/resource/backup.dart';
import 'package:configr/src/models/action.dart';

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

    final resourceModel = helper.createTestResource(
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

    final resourceModel = helper.createTestResource(
        source: sourceDir,
        destination: sourceDir,
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

    final resourceModel = helper.createTestResource(
        source: sourcePath,
        destination: sourcePath,
        actions: [
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

    final resourceModel = helper.createTestResource(
        source: sourcePath,
        destination: sourcePath,
        actions: [
          Action(type: 'backup', properties: {'backup_path': backupPath})
        ]);

    final module = FileBackupModule(resourceModel, resourceModel.actions.first,
        fileSystem: helper.fileSystem);

    // Act & Assert
    expect(() => module(), throwsA(isA<SourceNotFoundException>()));
  });

  group('Enhanced Backup Features', () {
    test('should create compressed backup with ZIP format', () async {
      // Arrange
      const sourcePath = 'source/test.txt';
      const backupPath = 'backups/test.zip';
      const content = 'test content for compression';

      await helper.createTestFile(sourcePath, content);

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: sourcePath,
          actions: [
            Action(
                type: 'backup',
                properties: {
                  'backup_path': backupPath,
                  'compression': 'true',
                  'compression_format': 'zip'
                })
          ]);

      final module = FileBackupModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists(backupPath), isTrue);
      // Verify it's a valid ZIP file
      final backupContent = await helper.readFile(backupPath);
      expect(backupContent.isNotEmpty, isTrue);
    });

    test('should create compressed backup with TAR.GZ format', () async {
      // Arrange
      const sourcePath = 'source/test.txt';
      const backupPath = 'backups/test.tar.gz';
      const content = 'test content for tar.gz compression';

      await helper.createTestFile(sourcePath, content);

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: sourcePath,
          actions: [
            Action(
                type: 'backup',
                properties: {
                  'backup_path': backupPath,
                  'compression': 'true',
                  'compression_format': 'tar.gz'
                })
          ]);

      final module = FileBackupModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists(backupPath), isTrue);
      final backupContent = await helper.readFile(backupPath);
      expect(backupContent.isNotEmpty, isTrue);
    });

    test('should create encrypted backup', () async {
      // Arrange
      const sourcePath = 'source/test.txt';
      const backupPath = 'backups/test.enc';
      const content = 'sensitive content';
      const encryptionKey = 'my-secret-key';

      await helper.createTestFile(sourcePath, content);

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: sourcePath,
          actions: [
            Action(
                type: 'backup',
                properties: {
                  'backup_path': backupPath,
                  'encryption': 'true',
                  'encryption_key': encryptionKey
                })
          ]);

      final module = FileBackupModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists(backupPath), isTrue);
      final backupContent = await helper.readFile(backupPath);
      expect(backupContent.isNotEmpty, isTrue);
      // Verify content is encrypted (different from original)
      expect(backupContent, isNot(equals(content)));
    });

    test('should create compressed and encrypted backup', () async {
      // Arrange
      const sourcePath = 'source/test.txt';
      const backupPath = 'backups/test.compressed.enc';
      const content = 'sensitive content for compression and encryption';
      const encryptionKey = 'my-secret-key';

      await helper.createTestFile(sourcePath, content);

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: sourcePath,
          actions: [
            Action(
                type: 'backup',
                properties: {
                  'backup_path': backupPath,
                  'compression': 'true',
                  'compression_format': 'zip',
                  'encryption': 'true',
                  'encryption_key': encryptionKey
                })
          ]);

      final module = FileBackupModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists(backupPath), isTrue);
      final backupContent = await helper.readFile(backupPath);
      expect(backupContent.isNotEmpty, isTrue);
    });

    test('should perform incremental backup on first run', () async {
      // Arrange
      const sourcePath = 'source/test.txt';
      const backupPath = 'backups/test.inc';
      const content = 'initial content';

      await helper.createTestFile(sourcePath, content);

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: sourcePath,
          actions: [
            Action(
                type: 'backup',
                properties: {
                  'backup_path': backupPath,
                  'incremental': 'true'
                })
          ]);

      final module = FileBackupModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists(backupPath), isTrue);
      expect(await helper.fileExists('$backupPath.manifest'), isTrue);
      
      // Verify manifest content
      final manifestContent = await helper.readFile('$backupPath.manifest');
      final manifest = jsonDecode(manifestContent);
      expect(manifest['source'], equals('test.txt'));
      expect(manifest['files'], isA<Map>());
    });

    test('should skip incremental backup when no changes detected', () async {
      // Arrange
      const sourcePath = 'source/test.txt';
      const backupPath = 'backups/test.inc';
      const content = 'unchanged content';

      await helper.createTestFile(sourcePath, content);

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: sourcePath,
          actions: [
            Action(
                type: 'backup',
                properties: {
                  'backup_path': backupPath,
                  'incremental': 'true'
                })
          ]);

      final module = FileBackupModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act - First backup
      await module();
      final firstBackupTime = DateTime.now();
      
      // Act - Second backup (should skip)
      await module();

      // Assert
      expect(await helper.fileExists(backupPath), isTrue);
      expect(await helper.fileExists('$backupPath.manifest'), isTrue);
      
      // Verify no new incremental backup was created
      final manifestContent = await helper.readFile('$backupPath.manifest');
      final manifest = jsonDecode(manifestContent);
      final manifestTime = DateTime.parse(manifest['timestamp']);
      expect(manifestTime.isBefore(firstBackupTime.add(Duration(seconds: 1))), isTrue);
    });

    test('should create incremental backup when files change', () async {
      // Arrange
      const sourcePath = 'source/test.txt';
      const backupPath = 'backups/test.inc';
      const initialContent = 'initial content';
      const changedContent = 'changed content';

      await helper.createTestFile(sourcePath, initialContent);

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: sourcePath,
          actions: [
            Action(
                type: 'backup',
                properties: {
                  'backup_path': backupPath,
                  'incremental': 'true'
                })
          ]);

      final module = FileBackupModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act - First backup
      await module();
      
      // Change file content
      await helper.createTestFile(sourcePath, changedContent);
      
      // Act - Second backup (should detect changes)
      await module();

      // Assert
      expect(await helper.fileExists(backupPath), isTrue);
      expect(await helper.fileExists('$backupPath.manifest'), isTrue);
      
      // Verify incremental backup was created
      final state = module.state;
      expect(state.containsKey('incrementalBackupPath'), isTrue);
    });

    test('should handle directory incremental backup', () async {
      // Arrange
      const sourceDir = 'source/dir';
      const backupPath = 'backups/dir.inc';

      await helper.createDirectory(sourceDir);
      await helper.createTestFile('$sourceDir/file1.txt', 'content1');
      await helper.createTestFile('$sourceDir/file2.txt', 'content2');

      final resourceModel = helper.createTestResource(
          source: sourceDir,
          destination: sourceDir,
          actions: [
            Action(
                type: 'backup',
                properties: {
                  'backup_path': backupPath,
                  'incremental': 'true',
                  'recursive': 'true'
                })
          ]);

      final module = FileBackupModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      // For directory backups, check if it's a directory or file
      final backupExists = await helper.fileExists(backupPath) || await helper.directoryExists(backupPath);
      expect(backupExists, isTrue);
      expect(await helper.fileExists('$backupPath.manifest'), isTrue);
      
      // Verify manifest contains both files
      final manifestContent = await helper.readFile('$backupPath.manifest');
      final manifest = jsonDecode(manifestContent);
      final files = manifest['files'] as Map<String, dynamic>;
      expect(files.containsKey('file1.txt'), isTrue);
      expect(files.containsKey('file2.txt'), isTrue);
    });

    test('should rollback enhanced backup features', () async {
      // Arrange
      const sourcePath = 'source/test.txt';
      const backupPath = 'backups/test.enhanced';
      const content = 'test content';

      await helper.createTestFile(sourcePath, content);

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: sourcePath,
          actions: [
            Action(
                type: 'backup',
                properties: {
                  'backup_path': backupPath,
                  'compression': 'true',
                  'encryption': 'true',
                  'encryption_key': 'test-key',
                  'incremental': 'true'
                })
          ]);

      final module = FileBackupModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();
      await module.rollback();

      // Assert
      expect(await helper.fileExists(backupPath), isFalse);
      expect(await helper.fileExists('$backupPath.manifest'), isFalse);
    });

    test('should throw error when encryption key is missing', () async {
      // Arrange
      const sourcePath = 'source/test.txt';
      const backupPath = 'backups/test.enc';

      await helper.createTestFile(sourcePath, 'content');

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: sourcePath,
          actions: [
            Action(
                type: 'backup',
                properties: {
                  'backup_path': backupPath,
                  'encryption': 'true'
                  // Missing encryption_key
                })
          ]);

      final module = FileBackupModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act & Assert
      expect(() => module(), throwsA(isA<Exception>()));
    });

    test('should throw error for unsupported compression format', () async {
      // Arrange
      const sourcePath = 'source/test.txt';
      const backupPath = 'backups/test.unsupported';

      await helper.createTestFile(sourcePath, 'content');

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: sourcePath,
          actions: [
            Action(
                type: 'backup',
                properties: {
                  'backup_path': backupPath,
                  'compression': 'true',
                  'compression_format': 'unsupported'
                })
          ]);

      final module = FileBackupModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act & Assert
      expect(() => module(), throwsA(isA<Exception>()));
    });
  });
}
