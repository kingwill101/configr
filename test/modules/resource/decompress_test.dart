import 'package:test/test.dart';
import 'package:configr/src/modules/resource/decompress.dart';
import 'package:configr/src/modules/resource/compress.dart';
import 'package:configr/src/models/action.dart';
import 'package:configr/src/exceptions.dart';
import '../../helpers/test_helper.dart';

void main() {
  late TestHelper helper;

  setUp(() {
    helper = TestHelper();
  });

  group('FileDecompressModule', () {
    test('should decompress ZIP archive successfully', () async {
      // Arrange - Create a ZIP archive first
      const sourcePath = 'source';
      const archivePath = 'dest/archive.zip';
      const extractPath = 'extracted';
      
      await helper.createDirectory(sourcePath);
      await helper.createTestFile('$sourcePath/file1.txt', 'content1');
      await helper.createTestFile('$sourcePath/file2.txt', 'content2');
      await helper.createDirectory('$sourcePath/subdir');
      await helper.createTestFile('$sourcePath/subdir/file3.txt', 'content3');

      // Create ZIP archive
      final compressResource = helper.createTestResource(
          source: sourcePath,
          destination: archivePath,
          actions: [
            Action(
                type: 'compress',
                properties: {'format': 'zip', 'recursive': 'true'})
          ]);

      final compressModule = FileCompressModule(
          compressResource, compressResource.actions.first,
          fileSystem: helper.fileSystem);

      await compressModule();

      // Now decompress it
      final decompressResource = helper.createTestResource(
          source: archivePath,
          destination: extractPath,
          actions: [
            Action(type: 'decompress', properties: {'format': 'zip'})
          ]);

      final decompressModule = FileDecompressModule(
          decompressResource, decompressResource.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await decompressModule();

      // Assert
      expect(await helper.fileExists('$extractPath/file1.txt'), isTrue);
      expect(await helper.fileExists('$extractPath/file2.txt'), isTrue);
      expect(await helper.fileExists('$extractPath/subdir/file3.txt'), isTrue);
      expect(await helper.readFile('$extractPath/file1.txt'), equals('content1'));
      expect(await helper.readFile('$extractPath/file2.txt'), equals('content2'));
      expect(await helper.readFile('$extractPath/subdir/file3.txt'), equals('content3'));
    });

    test('should decompress TAR.GZ archive successfully', () async {
      // Arrange - Create a TAR.GZ archive first
      const sourcePath = 'source_tar';
      const archivePath = 'dest/archive.tar.gz';
      const extractPath = 'extracted_tar';
      
      await helper.createDirectory(sourcePath);
      await helper.createTestFile('$sourcePath/file1.txt', 'content1');
      await helper.createTestFile('$sourcePath/file2.txt', 'content2');

      // Create TAR.GZ archive
      final compressResource = helper.createTestResource(
          source: sourcePath,
          destination: archivePath,
          actions: [
            Action(
                type: 'compress',
                properties: {'format': 'tar.gz', 'recursive': 'true'})
          ]);

      final compressModule = FileCompressModule(
          compressResource, compressResource.actions.first,
          fileSystem: helper.fileSystem);

      await compressModule();

      // Now decompress it
      final decompressResource = helper.createTestResource(
          source: archivePath,
          destination: extractPath,
          actions: [
            Action(type: 'decompress', properties: {'format': 'tar.gz'})
          ]);

      final decompressModule = FileDecompressModule(
          decompressResource, decompressResource.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await decompressModule();

      // Assert
      expect(await helper.fileExists('$extractPath/file1.txt'), isTrue);
      expect(await helper.fileExists('$extractPath/file2.txt'), isTrue);
      expect(await helper.readFile('$extractPath/file1.txt'), equals('content1'));
      expect(await helper.readFile('$extractPath/file2.txt'), equals('content2'));
    });

    test('should decompress GZ single file successfully', () async {
      // Arrange - Create a GZ file first
      const sourcePath = 'source_file.txt';
      const archivePath = 'dest/archive.gz';
      const extractPath = 'extracted_gz';
      
      await helper.createTestFile(sourcePath, 'test content for gzip compression');

      // Create GZ archive
      final compressResource = helper.createTestResource(
          source: sourcePath,
          destination: archivePath,
          actions: [
            Action(type: 'compress', properties: {'format': 'gz'})
          ]);

      final compressModule = FileCompressModule(
          compressResource, compressResource.actions.first,
          fileSystem: helper.fileSystem);

      await compressModule();

      // Now decompress it
      final decompressResource = helper.createTestResource(
          source: archivePath,
          destination: extractPath,
          actions: [
            Action(type: 'decompress', properties: {'format': 'gz'})
          ]);

      final decompressModule = FileDecompressModule(
          decompressResource, decompressResource.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await decompressModule();

      // Assert - GZ format doesn't preserve original filename, so we expect the filename without .gz extension
      expect(await helper.fileExists('$extractPath/archive'), isTrue);
      expect(await helper.readFile('$extractPath/archive'), equals('test content for gzip compression'));
    });

    test('should support selective extraction with include patterns', () async {
      // Arrange - Create a ZIP archive with multiple files
      const sourcePath = 'source_selective';
      const archivePath = 'dest/selective.zip';
      const extractPath = 'extracted_selective';
      
      await helper.createDirectory(sourcePath);
      await helper.createTestFile('$sourcePath/file1.txt', 'content1');
      await helper.createTestFile('$sourcePath/file2.log', 'content2');
      await helper.createTestFile('$sourcePath/file3.txt', 'content3');
      await helper.createTestFile('$sourcePath/file4.log', 'content4');

      // Create ZIP archive
      final compressResource = helper.createTestResource(
          source: sourcePath,
          destination: archivePath,
          actions: [
            Action(
                type: 'compress',
                properties: {'format': 'zip', 'recursive': 'true'})
          ]);

      final compressModule = FileCompressModule(
          compressResource, compressResource.actions.first,
          fileSystem: helper.fileSystem);

      await compressModule();

      // Now decompress with include pattern (only .txt files)
      final decompressResource = helper.createTestResource(
          source: archivePath,
          destination: extractPath,
          actions: [
            Action(
                type: 'decompress', 
                properties: {
                  'format': 'zip',
                  'include': '*.txt'
                })
          ]);

      final decompressModule = FileDecompressModule(
          decompressResource, decompressResource.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await decompressModule();

      // Assert
      expect(await helper.fileExists('$extractPath/file1.txt'), isTrue);
      expect(await helper.fileExists('$extractPath/file3.txt'), isTrue);
      expect(await helper.fileExists('$extractPath/file2.log'), isFalse);
      expect(await helper.fileExists('$extractPath/file4.log'), isFalse);
    });

    test('should support selective extraction with exclude patterns', () async {
      // Arrange - Create a ZIP archive with multiple files
      const sourcePath = 'source_exclude';
      const archivePath = 'dest/exclude.zip';
      const extractPath = 'extracted_exclude';
      
      await helper.createDirectory(sourcePath);
      await helper.createTestFile('$sourcePath/file1.txt', 'content1');
      await helper.createTestFile('$sourcePath/file2.log', 'content2');
      await helper.createTestFile('$sourcePath/file3.txt', 'content3');
      await helper.createTestFile('$sourcePath/file4.log', 'content4');

      // Create ZIP archive
      final compressResource = helper.createTestResource(
          source: sourcePath,
          destination: archivePath,
          actions: [
            Action(
                type: 'compress',
                properties: {'format': 'zip', 'recursive': 'true'})
          ]);

      final compressModule = FileCompressModule(
          compressResource, compressResource.actions.first,
          fileSystem: helper.fileSystem);

      await compressModule();

      // Now decompress with exclude pattern (exclude .log files)
      final decompressResource = helper.createTestResource(
          source: archivePath,
          destination: extractPath,
          actions: [
            Action(
                type: 'decompress', 
                properties: {
                  'format': 'zip',
                  'exclude': '*.log'
                })
          ]);

      final decompressModule = FileDecompressModule(
          decompressResource, decompressResource.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await decompressModule();

      // Assert
      expect(await helper.fileExists('$extractPath/file1.txt'), isTrue);
      expect(await helper.fileExists('$extractPath/file3.txt'), isTrue);
      expect(await helper.fileExists('$extractPath/file2.log'), isFalse);
      expect(await helper.fileExists('$extractPath/file4.log'), isFalse);
    });

    test('should support preserveStructure=false to flatten directory structure', () async {
      // Arrange - Create a ZIP archive with nested directories
      const sourcePath = 'source_nested';
      const archivePath = 'dest/nested.zip';
      const extractPath = 'extracted_flat';
      
      await helper.createDirectory(sourcePath);
      await helper.createDirectory('$sourcePath/subdir1');
      await helper.createDirectory('$sourcePath/subdir2');
      await helper.createTestFile('$sourcePath/file1.txt', 'content1');
      await helper.createTestFile('$sourcePath/subdir1/file2.txt', 'content2');
      await helper.createTestFile('$sourcePath/subdir2/file3.txt', 'content3');

      // Create ZIP archive
      final compressResource = helper.createTestResource(
          source: sourcePath,
          destination: archivePath,
          actions: [
            Action(
                type: 'compress',
                properties: {'format': 'zip', 'recursive': 'true'})
          ]);

      final compressModule = FileCompressModule(
          compressResource, compressResource.actions.first,
          fileSystem: helper.fileSystem);

      await compressModule();

      // Now decompress with preserveStructure=false
      final decompressResource = helper.createTestResource(
          source: archivePath,
          destination: extractPath,
          actions: [
            Action(
                type: 'decompress', 
                properties: {
                  'format': 'zip',
                  'preserveStructure': 'false'
                })
          ]);

      final decompressModule = FileDecompressModule(
          decompressResource, decompressResource.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await decompressModule();

      // Assert - All files should be in the root extraction directory
      expect(await helper.fileExists('$extractPath/file1.txt'), isTrue);
      expect(await helper.fileExists('$extractPath/file2.txt'), isTrue);
      expect(await helper.fileExists('$extractPath/file3.txt'), isTrue);
      expect(await helper.directoryExists('$extractPath/subdir1'), isFalse);
      expect(await helper.directoryExists('$extractPath/subdir2'), isFalse);
    });

    test('should track progress during extraction', () async {
      // Arrange - Create a ZIP archive with many files
      const sourcePath = 'source_progress';
      const archivePath = 'dest/progress.zip';
      const extractPath = 'extracted_progress';
      
      await helper.createDirectory(sourcePath);
      
      // Create 25 files to test progress tracking
      for (int i = 1; i <= 25; i++) {
        await helper.createTestFile('$sourcePath/file$i.txt', 'content$i');
      }

      // Create ZIP archive
      final compressResource = helper.createTestResource(
          source: sourcePath,
          destination: archivePath,
          actions: [
            Action(
                type: 'compress',
                properties: {'format': 'zip', 'recursive': 'true'})
          ]);

      final compressModule = FileCompressModule(
          compressResource, compressResource.actions.first,
          fileSystem: helper.fileSystem);

      await compressModule();

      // Now decompress
      final decompressResource = helper.createTestResource(
          source: archivePath,
          destination: extractPath,
          actions: [
            Action(type: 'decompress', properties: {'format': 'zip'})
          ]);

      final decompressModule = FileDecompressModule(
          decompressResource, decompressResource.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await decompressModule();

      // Assert
      expect(decompressModule.totalFiles, equals(25));
      expect(decompressModule.extractedFiles, equals(25));
      expect(decompressModule.state['totalFiles'], equals(25));
      expect(decompressModule.state['extractedFiles'], equals(25));
    });

    test('should throw error for unsupported format', () async {
      // Arrange
      const archivePath = 'dest/unsupported.7z';
      const extractPath = 'extracted_unsupported';
      
      // Create a dummy file
      await helper.createTestFile(archivePath, 'dummy content');

      final decompressResource = helper.createTestResource(
          source: archivePath,
          destination: extractPath,
          actions: [
            Action(type: 'decompress', properties: {'format': '7z'})
          ]);

      final decompressModule = FileDecompressModule(
          decompressResource, decompressResource.actions.first,
          fileSystem: helper.fileSystem);

      // Act & Assert
      expect(
        () => decompressModule(),
        throwsA(isA<ActionFailedException>()),
      );
    });

    test('should decompress TAR.BZ2 archive successfully', () async {
      // Arrange - Create a TAR.BZ2 archive first
      const sourcePath = 'source_bz2';
      const archivePath = 'dest/archive.tar.bz2';
      const extractPath = 'extracted_bz2';
      
      await helper.createDirectory(sourcePath);
      await helper.createTestFile('$sourcePath/file1.txt', 'content1');
      await helper.createTestFile('$sourcePath/file2.txt', 'content2');

      // Create TAR.BZ2 archive using compress module
      final compressResource = helper.createTestResource(
          source: sourcePath,
          destination: archivePath,
          actions: [
            Action(
                type: 'compress',
                properties: {'format': 'tar.bz2', 'recursive': 'true'})
          ]);

      final compressModule = FileCompressModule(
          compressResource, compressResource.actions.first,
          fileSystem: helper.fileSystem);

      await compressModule();

      // Now decompress it
      final decompressResource = helper.createTestResource(
          source: archivePath,
          destination: extractPath,
          actions: [
            Action(type: 'decompress', properties: {'format': 'tar.bz2'})
          ]);

      final decompressModule = FileDecompressModule(
          decompressResource, decompressResource.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await decompressModule();

      // Assert
      expect(await helper.fileExists('$extractPath/file1.txt'), isTrue);
      expect(await helper.fileExists('$extractPath/file2.txt'), isTrue);
      expect(await helper.readFile('$extractPath/file1.txt'), equals('content1'));
      expect(await helper.readFile('$extractPath/file2.txt'), equals('content2'));
    });

    test('should throw error when source file does not exist', () async {
      // Arrange
      const archivePath = 'nonexistent/archive.zip';
      const extractPath = 'extracted_nonexistent';

      final decompressResource = helper.createTestResource(
          source: archivePath,
          destination: extractPath,
          actions: [
            Action(type: 'decompress', properties: {'format': 'zip'})
          ]);

      final decompressModule = FileDecompressModule(
          decompressResource, decompressResource.actions.first,
          fileSystem: helper.fileSystem);

      // Act & Assert
      expect(
        () => decompressModule(),
        throwsA(isA<SourceNotFoundException>()),
      );
    });

    test('should support TGZ format alias', () async {
      // Arrange - Create a TAR.GZ archive first
      const sourcePath = 'source_tgz';
      const archivePath = 'dest/archive.tgz';
      const extractPath = 'extracted_tgz';
      
      await helper.createDirectory(sourcePath);
      await helper.createTestFile('$sourcePath/file1.txt', 'content1');

      // Create TAR.GZ archive
      final compressResource = helper.createTestResource(
          source: sourcePath,
          destination: archivePath,
          actions: [
            Action(
                type: 'compress',
                properties: {'format': 'tar.gz', 'recursive': 'true'})
          ]);

      final compressModule = FileCompressModule(
          compressResource, compressResource.actions.first,
          fileSystem: helper.fileSystem);

      await compressModule();

      // Now decompress using TGZ format
      final decompressResource = helper.createTestResource(
          source: archivePath,
          destination: extractPath,
          actions: [
            Action(type: 'decompress', properties: {'format': 'tgz'})
          ]);

      final decompressModule = FileDecompressModule(
          decompressResource, decompressResource.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await decompressModule();

      // Assert
      expect(await helper.fileExists('$extractPath/file1.txt'), isTrue);
      expect(await helper.readFile('$extractPath/file1.txt'), equals('content1'));
    });

    test('should support TBZ2 format alias', () async {
      // Arrange - Create a TAR.BZ2 archive first
      const sourcePath = 'source_tbz2';
      const archivePath = 'dest/archive.tbz2';
      const extractPath = 'extracted_tbz2';
      
      await helper.createDirectory(sourcePath);
      await helper.createTestFile('$sourcePath/file1.txt', 'content1');

      // Create TAR.BZ2 archive using compress module
      final compressResource = helper.createTestResource(
          source: sourcePath,
          destination: archivePath,
          actions: [
            Action(
                type: 'compress',
                properties: {'format': 'tar.bz2', 'recursive': 'true'})
          ]);

      final compressModule = FileCompressModule(
          compressResource, compressResource.actions.first,
          fileSystem: helper.fileSystem);

      await compressModule();

      // Now decompress using TBZ2 format
      final decompressResource = helper.createTestResource(
          source: archivePath,
          destination: extractPath,
          actions: [
            Action(type: 'decompress', properties: {'format': 'tbz2'})
          ]);

      final decompressModule = FileDecompressModule(
          decompressResource, decompressResource.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await decompressModule();

      // Assert
      expect(await helper.fileExists('$extractPath/file1.txt'), isTrue);
      expect(await helper.readFile('$extractPath/file1.txt'), equals('content1'));
    });

    test('should handle complex include/exclude patterns', () async {
      // Arrange - Create a ZIP archive with various file types
      const sourcePath = 'source_complex';
      const archivePath = 'dest/complex.zip';
      const extractPath = 'extracted_complex';
      
      await helper.createDirectory(sourcePath);
      await helper.createTestFile('$sourcePath/app.js', 'js content');
      await helper.createTestFile('$sourcePath/app.min.js', 'minified js');
      await helper.createTestFile('$sourcePath/style.css', 'css content');
      await helper.createTestFile('$sourcePath/style.min.css', 'minified css');
      await helper.createTestFile('$sourcePath/readme.txt', 'readme content');
      await helper.createTestFile('$sourcePath/config.json', 'json content');

      // Create ZIP archive
      final compressResource = helper.createTestResource(
          source: sourcePath,
          destination: archivePath,
          actions: [
            Action(
                type: 'compress',
                properties: {'format': 'zip', 'recursive': 'true'})
          ]);

      final compressModule = FileCompressModule(
          compressResource, compressResource.actions.first,
          fileSystem: helper.fileSystem);

      await compressModule();

      // Now decompress with complex patterns (include .js and .css, exclude .min.*)
      final decompressResource = helper.createTestResource(
          source: archivePath,
          destination: extractPath,
          actions: [
            Action(
                type: 'decompress', 
                properties: {
                  'format': 'zip',
                  'include': '*.js,*.css',
                  'exclude': '*.min.*'
                })
          ]);

      final decompressModule = FileDecompressModule(
          decompressResource, decompressResource.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await decompressModule();

      // Assert
      expect(await helper.fileExists('$extractPath/app.js'), isTrue);
      expect(await helper.fileExists('$extractPath/style.css'), isTrue);
      expect(await helper.fileExists('$extractPath/app.min.js'), isFalse);
      expect(await helper.fileExists('$extractPath/style.min.css'), isFalse);
      expect(await helper.fileExists('$extractPath/readme.txt'), isFalse);
      expect(await helper.fileExists('$extractPath/config.json'), isFalse);
    });
  });
}
