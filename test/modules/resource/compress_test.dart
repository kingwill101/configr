import 'package:test/test.dart';
import 'package:configr/modules/resource/compress.dart';
import 'package:configr/models/action.dart';
import 'package:configr/exceptions.dart';
import '../../helpers/test_helper.dart';

void main() {
  late TestHelper helper;

  setUp(() {
    helper = TestHelper();
  });

  group('FileCompressModule', () {
    test('should compress directory successfully with ZIP format', () async {
      // Arrange
      const sourcePath = 'source';
      const destPath = 'dest/archive.zip';
      await helper.createDirectory(sourcePath);
      assert(await helper.directoryExists(sourcePath));
      await helper.createTestFile('$sourcePath/file1.txt', 'content1');
      await helper.createTestFile('$sourcePath/file2.txt', 'content2');

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: destPath,
          actions: [
            Action(
                type: 'compress',
                properties: {'format': 'zip', 'recursive': 'true'})
          ]);

      final module = FileCompressModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      final archive = helper.fileSystem.file(module.destination);
      expect(await archive.exists(), isTrue);
      expect(await archive.length(), greaterThan(0));
    });

    test('should compress directory with TAR.GZ format', () async {
      // Arrange
      const sourcePath = 'source_tar';
      const destPath = 'dest/archive.tar.gz';
      await helper.createDirectory(sourcePath);
      await helper.createTestFile('$sourcePath/file1.txt', 'content1');
      await helper.createTestFile('$sourcePath/file2.txt', 'content2');

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: destPath,
          actions: [
            Action(
                type: 'compress',
                properties: {'format': 'tar.gz', 'recursive': 'true'})
          ]);

      final module = FileCompressModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      final archive = helper.fileSystem.file(module.destination);
      expect(await archive.exists(), isTrue);
      expect(await archive.length(), greaterThan(0));
    });

    test('should compress single file with GZ format', () async {
      // Arrange
      const sourcePath = 'source_file.txt';
      const destPath = 'dest/archive.gz';
      await helper.createTestFile(sourcePath, 'test content for compression');

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: destPath,
          actions: [
            Action(type: 'compress', properties: {'format': 'gz'})
          ]);

      final module = FileCompressModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      final archive = helper.fileSystem.file(module.destination);
      expect(await archive.exists(), isTrue);
      expect(await archive.length(), greaterThan(0));
    });

    test('should apply compression levels to GZ format', () async {
      // Arrange - Create a file with repetitive content
      const sourcePath = 'source_gz_test.txt';
      final testContent = 'This is repetitive content for GZ compression testing. ' * 50;
      await helper.createTestFile(sourcePath, testContent);

      // Test with compression level 1
      final resourceModel1 = helper.createTestResource(
          source: sourcePath,
          destination: 'dest/archive_level1.gz',
          actions: [
            Action(
                type: 'compress',
                properties: {'format': 'gz', 'compressionLevel': '1'})
          ]);

      final module1 = FileCompressModule(
          resourceModel1, resourceModel1.actions.first,
          fileSystem: helper.fileSystem);

      // Test with compression level 9
      final resourceModel9 = helper.createTestResource(
          source: sourcePath,
          destination: 'dest/archive_level9.gz',
          actions: [
            Action(
                type: 'compress',
                properties: {'format': 'gz', 'compressionLevel': '9'})
          ]);

      final module9 = FileCompressModule(
          resourceModel9, resourceModel9.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module1();
      await module9();

      // Assert
      final archive1 = helper.fileSystem.file(module1.destination);
      final archive9 = helper.fileSystem.file(module9.destination);
      
      expect(await archive1.exists(), isTrue);
      expect(await archive9.exists(), isTrue);
      
      final size1 = await archive1.length();
      final size9 = await archive9.length();
      
      // Level 9 should produce smaller files than level 1 for repetitive content
      expect(size9, lessThanOrEqualTo(size1));
      
      // Both should be significantly smaller than original content
      expect(size1, lessThan(testContent.length));
      expect(size9, lessThan(testContent.length));
    });

    test('should support compression level configuration', () async {
      // Arrange
      const sourcePath = 'source_level';
      const destPath = 'dest/archive_level.zip';
      await helper.createDirectory(sourcePath);
      await helper.createTestFile('$sourcePath/large_file.txt', 'x' * 1000);

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: destPath,
          actions: [
            Action(
                type: 'compress',
                properties: {
                  'format': 'zip',
                  'compressionLevel': '9',
                  'recursive': 'true'
                })
          ]);

      final module = FileCompressModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      final archive = helper.fileSystem.file(module.destination);
      expect(await archive.exists(), isTrue);
      expect(await archive.length(), greaterThan(0));
      expect(module.compressionLevel, equals(9));
    });

    test('should apply different compression levels effectively', () async {
      // Arrange - Create a file with repetitive content that compresses well
      const sourcePath = 'source_compression_test';
      final testContent = 'This is a test file with repetitive content. ' * 100;
      await helper.createDirectory(sourcePath);
      await helper.createTestFile('$sourcePath/test.txt', testContent);

      // Test with compression level 1 (fastest, least compression)
      final resourceModel1 = helper.createTestResource(
          source: sourcePath,
          destination: 'dest/archive_level1.zip',
          actions: [
            Action(
                type: 'compress',
                properties: {
                  'format': 'zip',
                  'compressionLevel': '1',
                  'recursive': 'true'
                })
          ]);

      final module1 = FileCompressModule(
          resourceModel1, resourceModel1.actions.first,
          fileSystem: helper.fileSystem);

      // Test with compression level 9 (slowest, best compression)
      final resourceModel9 = helper.createTestResource(
          source: sourcePath,
          destination: 'dest/archive_level9.zip',
          actions: [
            Action(
                type: 'compress',
                properties: {
                  'format': 'zip',
                  'compressionLevel': '9',
                  'recursive': 'true'
                })
          ]);

      final module9 = FileCompressModule(
          resourceModel9, resourceModel9.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module1();
      await module9();

      // Assert
      final archive1 = helper.fileSystem.file(module1.destination);
      final archive9 = helper.fileSystem.file(module9.destination);
      
      expect(await archive1.exists(), isTrue);
      expect(await archive9.exists(), isTrue);
      
      final size1 = await archive1.length();
      final size9 = await archive9.length();
      
      // Level 9 should produce smaller files than level 1 for repetitive content
      expect(size9, lessThanOrEqualTo(size1));
      
      // Both should be significantly smaller than original content
      expect(size1, lessThan(testContent.length));
      expect(size9, lessThan(testContent.length));
    });

    test('should support include patterns for selective compression', () async {
      // Arrange
      const sourcePath = 'source_include';
      const destPath = 'dest/archive_include.zip';
      await helper.createDirectory(sourcePath);
      await helper.createTestFile('$sourcePath/file1.txt', 'content1');
      await helper.createTestFile('$sourcePath/file2.log', 'content2');
      await helper.createTestFile('$sourcePath/file3.txt', 'content3');

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: destPath,
          actions: [
            Action(
                type: 'compress',
                properties: {
                  'format': 'zip',
                  'include': '*.txt',
                  'recursive': 'true'
                })
          ]);

      final module = FileCompressModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      final archive = helper.fileSystem.file(module.destination);
      expect(await archive.exists(), isTrue);
      expect(await archive.length(), greaterThan(0));
      expect(module.includePatterns, contains('*.txt'));
    });

    test('should support exclude patterns for selective compression', () async {
      // Arrange
      const sourcePath = 'source_exclude';
      const destPath = 'dest/archive_exclude.zip';
      await helper.createDirectory(sourcePath);
      await helper.createTestFile('$sourcePath/file1.txt', 'content1');
      await helper.createTestFile('$sourcePath/file2.log', 'content2');
      await helper.createTestFile('$sourcePath/file3.txt', 'content3');

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: destPath,
          actions: [
            Action(
                type: 'compress',
                properties: {
                  'format': 'zip',
                  'exclude': '*.log',
                  'recursive': 'true'
                })
          ]);

      final module = FileCompressModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      final archive = helper.fileSystem.file(module.destination);
      expect(await archive.exists(), isTrue);
      expect(await archive.length(), greaterThan(0));
      expect(module.excludePatterns, contains('*.log'));
    });

    test('should support preserveStructure configuration', () async {
      // Arrange
      const sourcePath = 'source_structure';
      const destPath = 'dest/archive_structure.zip';
      await helper.createDirectory(sourcePath);
      await helper.createTestFile('$sourcePath/subdir/file1.txt', 'content1');

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: destPath,
          actions: [
            Action(
                type: 'compress',
                properties: {
                  'format': 'zip',
                  'preserveStructure': 'false',
                  'recursive': 'true'
                })
          ]);

      final module = FileCompressModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      final archive = helper.fileSystem.file(module.destination);
      expect(await archive.exists(), isTrue);
      expect(await archive.length(), greaterThan(0));
      expect(module.preserveStructure, isFalse);
    });

    test('should throw error for unsupported format', () async {
      // Arrange
      const sourcePath = 'source_unsupported';
      const destPath = 'dest/archive.unsupported';
      await helper.createDirectory(sourcePath);
      await helper.createTestFile('$sourcePath/file1.txt', 'content1');

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: destPath,
          actions: [
            Action(
                type: 'compress',
                properties: {'format': 'unsupported', 'recursive': 'true'})
          ]);

      final module = FileCompressModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act & Assert
      expect(
        () => module(),
        throwsA(isA<ActionFailedException>()),
      );
    });

    test('should handle rollback correctly', () async {
      // Arrange
      const sourcePath = 'source_rollback';
      const destPath = 'dest/archive_rollback.zip';
      await helper.createDirectory(sourcePath);
      await helper.createTestFile('$sourcePath/file1.txt', 'content1');

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: destPath,
          actions: [
            Action(
                type: 'compress',
                properties: {'format': 'zip', 'recursive': 'true'})
          ]);

      final module = FileCompressModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act - Execute compression
      await module();
      
      // Verify file was created
      final archive = helper.fileSystem.file(module.destination);
      expect(await archive.exists(), isTrue);

      // Act - Rollback
      await module.rollback();

      // Assert - File should be deleted if it didn't exist before
      expect(await archive.exists(), isFalse);
    });

    test('should compress directory with TAR.BZ2 format', () async {
      // Arrange
      const sourcePath = 'source_bz2';
      const archivePath = 'dest/archive.tar.bz2';
      
      await helper.createDirectory(sourcePath);
      await helper.createTestFile('$sourcePath/file1.txt', 'content1');
      await helper.createTestFile('$sourcePath/file2.txt', 'content2');

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: archivePath,
          actions: [
            Action(
                type: 'compress',
                properties: {'format': 'tar.bz2', 'recursive': 'true'})
          ]);

      final module = FileCompressModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists(archivePath), isTrue);
      expect(module.state['format'], equals('tar.bz2'));
    });

    test('should compress directory with TAR.XZ format', () async {
      // Arrange
      const sourcePath = 'source_xz';
      const archivePath = 'dest/archive.tar.xz';
      
      await helper.createDirectory(sourcePath);
      await helper.createTestFile('$sourcePath/file1.txt', 'content1');

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: archivePath,
          actions: [
            Action(
                type: 'compress',
                properties: {'format': 'tar.xz', 'recursive': 'true'})
          ]);

      final module = FileCompressModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists(archivePath), isTrue);
      expect(module.state['format'], equals('tar.xz'));
    });

    test('should compress single file with XZ format', () async {
      // Arrange
      const sourcePath = 'source_file.txt';
      const archivePath = 'dest/archive.xz';
      await helper.createTestFile(sourcePath, 'test content for xz compression');

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: archivePath,
          actions: [
            Action(type: 'compress', properties: {'format': 'xz'})
          ]);

      final module = FileCompressModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists(archivePath), isTrue);
      expect(module.state['format'], equals('xz'));
    });

    test('should compress directory with TAR.Z format', () async {
      // Arrange
      const sourcePath = 'source_z';
      const archivePath = 'dest/archive.tar.z';
      
      await helper.createDirectory(sourcePath);
      await helper.createTestFile('$sourcePath/file1.txt', 'content1');

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: archivePath,
          actions: [
            Action(
                type: 'compress',
                properties: {'format': 'tar.z', 'recursive': 'true'})
          ]);

      final module = FileCompressModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists(archivePath), isTrue);
      expect(module.state['format'], equals('tar.z'));
    });

    test('should compress single file with Z format', () async {
      // Arrange
      const sourcePath = 'source_file.txt';
      const archivePath = 'dest/archive.z';
      await helper.createTestFile(sourcePath, 'test content for zlib compression');

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: archivePath,
          actions: [
            Action(type: 'compress', properties: {'format': 'z'})
          ]);

      final module = FileCompressModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists(archivePath), isTrue);
      expect(module.state['format'], equals('z'));
    });

    test('should support TBZ2 format alias', () async {
      // Arrange
      const sourcePath = 'source_tbz2';
      const archivePath = 'dest/archive.tbz2';
      
      await helper.createDirectory(sourcePath);
      await helper.createTestFile('$sourcePath/file1.txt', 'content1');

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: archivePath,
          actions: [
            Action(
                type: 'compress',
                properties: {'format': 'tbz2', 'recursive': 'true'})
          ]);

      final module = FileCompressModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists(archivePath), isTrue);
      expect(module.state['format'], equals('tbz2'));
    });

    test('should support TXZ format alias', () async {
      // Arrange
      const sourcePath = 'source_txz';
      const archivePath = 'dest/archive.txz';
      
      await helper.createDirectory(sourcePath);
      await helper.createTestFile('$sourcePath/file1.txt', 'content1');

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: archivePath,
          actions: [
            Action(
                type: 'compress',
                properties: {'format': 'txz', 'recursive': 'true'})
          ]);

      final module = FileCompressModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists(archivePath), isTrue);
      expect(module.state['format'], equals('txz'));
    });

    test('should support TZ format alias', () async {
      // Arrange
      const sourcePath = 'source_tz';
      const archivePath = 'dest/archive.tz';
      
      await helper.createDirectory(sourcePath);
      await helper.createTestFile('$sourcePath/file1.txt', 'content1');

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: archivePath,
          actions: [
            Action(
                type: 'compress',
                properties: {'format': 'tz', 'recursive': 'true'})
          ]);

      final module = FileCompressModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists(archivePath), isTrue);
      expect(module.state['format'], equals('tz'));
    });
  });
}
