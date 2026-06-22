import 'package:test/test.dart';
import 'package:configr/src/modules/resource/delete.dart';
import 'package:configr/src/models/action.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/utils/event_bus.dart';
import '../../helpers/test_helper.dart';

void main() {
  late TestHelper helper;

  setUp(() {
    helper = TestHelper();
  });

  test('should delete file successfully', () async {
    // Arrange
    const filePath = 'test/file.txt';
    const content = 'test content';
    await helper.createTestFile(filePath, content);

    final resourceModel = helper.createTestResource(
        source: filePath, destination: '', actions: [Action(type: 'delete')]);

    final module = FileDeleteModule(resourceModel, resourceModel.actions.first,
        fileSystem: helper.fileSystem);

    // Act
    await module();

    // Assert
    expect(await helper.fileExists(filePath), isFalse);
  });

  test('should create backup before deleting if specified', () async {
    // Arrange
    const filePath = 'test/file.txt';
    const backupPath = 'test/file.bak';
    const content = 'test content';
    await helper.createTestFile(filePath, content);

    final resourceModel =
        helper.createTestResource(source: filePath, destination: '', actions: [
      Action(type: 'delete', properties: {
        'backup': {'backup_path': backupPath}
      })
    ]);

    final module = FileDeleteModule(resourceModel, resourceModel.actions.first,
        fileSystem: helper.fileSystem);

    // Act
    await module();

    // Assert
    expect(await helper.fileExists(filePath), isFalse);
    expect(await helper.fileExists(backupPath), isTrue);
  });

  group('Enhanced Delete Features', () {
    test('should delete files with include patterns', () async {
      // Arrange
      const sourceDir = '/source/dir';
      const destDir = '/dest/dir';

      await helper.createDirectory(sourceDir);
      await helper.createTestFile('$sourceDir/file1.txt', 'content1');
      await helper.createTestFile('$sourceDir/file2.log', 'content2');
      await helper.createTestFile('$sourceDir/file3.txt', 'content3');

      final resourceModel = helper.createTestResource(
          source: sourceDir,
          destination: destDir,
          actions: [
            Action(
              type: 'delete',
              properties: {
                'recursive': 'true',
                'include': '*.txt'
              }
            )
          ]);

      final module = FileDeleteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists('$sourceDir/file1.txt'), isFalse);
      expect(await helper.fileExists('$sourceDir/file3.txt'), isFalse);
      expect(await helper.fileExists('$sourceDir/file2.log'), isTrue); // Should be excluded
      expect(module.deletedFiles, equals(2));
      expect(module.skippedFiles, equals(1));
    });

    test('should delete files with exclude patterns', () async {
      // Arrange
      const sourceDir = '/source/dir';
      const destDir = '/dest/dir';

      await helper.createDirectory(sourceDir);
      await helper.createTestFile('$sourceDir/file1.txt', 'content1');
      await helper.createTestFile('$sourceDir/file2.log', 'content2');
      await helper.createTestFile('$sourceDir/file3.txt', 'content3');

      final resourceModel = helper.createTestResource(
          source: sourceDir,
          destination: destDir,
          actions: [
            Action(
              type: 'delete',
              properties: {
                'recursive': 'true',
                'exclude': '*.log'
              }
            )
          ]);

      final module = FileDeleteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists('$sourceDir/file1.txt'), isFalse);
      expect(await helper.fileExists('$sourceDir/file3.txt'), isFalse);
      expect(await helper.fileExists('$sourceDir/file2.log'), isTrue); // Should be excluded
      expect(module.deletedFiles, equals(2));
      expect(module.skippedFiles, equals(1));
    });

    test('should use trash when configured', () async {
      // Arrange
      const filePath = '/test/file.txt';
      const content = 'test content';
      await helper.createTestFile(filePath, content);

      final resourceModel = helper.createTestResource(
          source: filePath,
          destination: '',
          actions: [
            Action(
              type: 'delete',
              properties: {
                'use_trash': 'true'
              }
            )
          ]);

      final module = FileDeleteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists(filePath), isFalse);
      expect(module.deletedFiles, equals(0)); // Not counted as deleted when trashed
      expect(module.trashedFiles, equals(1));
    });

    test('should require confirmation when configured', () async {
      // Arrange
      const filePath = '/test/file.txt';
      const content = 'test content';
      await helper.createTestFile(filePath, content);

      final resourceModel = helper.createTestResource(
          source: filePath,
          destination: '',
          actions: [
            Action(
              type: 'delete',
              properties: {
                'require_confirmation': 'true'
              }
            )
          ]);

      final module = FileDeleteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      final events = <ModuleEvent>[];
      eventBus.subscribe((event) {
        events.add(event);
      });

      // Act
      await module();

      // Assert
      expect(await helper.fileExists(filePath), isFalse); // Auto-confirmed for now
      expect(events.any((e) => e is StatusUpdateEvent && e.message.contains('Confirmation required')), isTrue);
    });

    test('should track progress for directory deletion', () async {
      // Arrange
      const sourceDir = '/source/dir';
      const destDir = '/dest/dir';

      await helper.createDirectory(sourceDir);
      await helper.createTestFile('$sourceDir/file1.txt', 'content1');
      await helper.createTestFile('$sourceDir/file2.txt', 'content2');
      await helper.createTestFile('$sourceDir/file3.txt', 'content3');

      final resourceModel = helper.createTestResource(
          source: sourceDir,
          destination: destDir,
          actions: [
            Action(
              type: 'delete',
              properties: {
                'recursive': 'true'
              }
            )
          ]);

      final module = FileDeleteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(module.totalFiles, equals(3));
      expect(module.deletedFiles, equals(3));
      expect(module.skippedFiles, equals(0));
    });

    test('should handle multiple include patterns', () async {
      // Arrange
      const sourceDir = '/source/dir';
      const destDir = '/dest/dir';

      await helper.createDirectory(sourceDir);
      await helper.createTestFile('$sourceDir/file1.txt', 'content1');
      await helper.createTestFile('$sourceDir/file2.log', 'content2');
      await helper.createTestFile('$sourceDir/file3.md', 'content3');
      await helper.createTestFile('$sourceDir/file4.dat', 'content4');

      final resourceModel = helper.createTestResource(
          source: sourceDir,
          destination: destDir,
          actions: [
            Action(
              type: 'delete',
              properties: {
                'recursive': 'true',
                'include': '*.txt,*.md'
              }
            )
          ]);

      final module = FileDeleteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists('$sourceDir/file1.txt'), isFalse);
      expect(await helper.fileExists('$sourceDir/file3.md'), isFalse);
      expect(await helper.fileExists('$sourceDir/file2.log'), isTrue);
      expect(await helper.fileExists('$sourceDir/file4.dat'), isTrue);
      expect(module.deletedFiles, equals(2));
      expect(module.skippedFiles, equals(2));
    });

    test('should handle multiple exclude patterns', () async {
      // Arrange
      const sourceDir = '/source/dir';
      const destDir = '/dest/dir';

      await helper.createDirectory(sourceDir);
      await helper.createTestFile('$sourceDir/file1.txt', 'content1');
      await helper.createTestFile('$sourceDir/file2.log', 'content2');
      await helper.createTestFile('$sourceDir/file3.tmp', 'content3');
      await helper.createTestFile('$sourceDir/file4.md', 'content4');

      final resourceModel = helper.createTestResource(
          source: sourceDir,
          destination: destDir,
          actions: [
            Action(
              type: 'delete',
              properties: {
                'recursive': 'true',
                'exclude': '*.log,*.tmp'
              }
            )
          ]);

      final module = FileDeleteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists('$sourceDir/file1.txt'), isFalse);
      expect(await helper.fileExists('$sourceDir/file4.md'), isFalse);
      expect(await helper.fileExists('$sourceDir/file2.log'), isTrue);
      expect(await helper.fileExists('$sourceDir/file3.tmp'), isTrue);
      expect(module.deletedFiles, equals(2));
      expect(module.skippedFiles, equals(2));
    });

    test('should emit progress events during directory deletion', () async {
      // Arrange
      const sourceDir = '/source/dir';
      const destDir = '/dest/dir';

      await helper.createDirectory(sourceDir);
      await helper.createTestFile('$sourceDir/file1.txt', 'content1');
      await helper.createTestFile('$sourceDir/file2.txt', 'content2');

      final resourceModel = helper.createTestResource(
          source: sourceDir,
          destination: destDir,
          actions: [
            Action(
              type: 'delete',
              properties: {
                'recursive': 'true'
              }
            )
          ]);

      final module = FileDeleteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      final events = <ModuleEvent>[];
      eventBus.subscribe((event) {
        events.add(event);
      });

      // Act
      await module();

      // Assert
      expect(events.any((e) => e is ProgressEvent), isTrue);
      expect(events.any((e) => e is StartedEvent), isTrue);
      expect(events.any((e) => e is CompletedEvent), isTrue);
    });

    test('should handle wildcard patterns correctly', () async {
      // Arrange
      const sourceDir = '/source/dir';
      const destDir = '/dest/dir';

      await helper.createDirectory(sourceDir);
      await helper.createTestFile('$sourceDir/test1.txt', 'content1');
      await helper.createTestFile('$sourceDir/test2.log', 'content2');
      await helper.createTestFile('$sourceDir/other.txt', 'content3');

      final resourceModel = helper.createTestResource(
          source: sourceDir,
          destination: destDir,
          actions: [
            Action(
              type: 'delete',
              properties: {
                'recursive': 'true',
                'include': 'test*'
              }
            )
          ]);

      final module = FileDeleteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists('$sourceDir/test1.txt'), isFalse);
      expect(await helper.fileExists('$sourceDir/test2.log'), isFalse);
      expect(await helper.fileExists('$sourceDir/other.txt'), isTrue);
      expect(module.deletedFiles, equals(2));
      expect(module.skippedFiles, equals(1));
    });

    test('should handle empty include patterns (delete all)', () async {
      // Arrange
      const sourceDir = '/source/dir';
      const destDir = '/dest/dir';

      await helper.createDirectory(sourceDir);
      await helper.createTestFile('$sourceDir/file1.txt', 'content1');
      await helper.createTestFile('$sourceDir/file2.log', 'content2');

      final resourceModel = helper.createTestResource(
          source: sourceDir,
          destination: destDir,
          actions: [
            Action(
              type: 'delete',
              properties: {
                'recursive': 'true'
                // No include patterns - should delete all
              }
            )
          ]);

      final module = FileDeleteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists('$sourceDir/file1.txt'), isFalse);
      expect(await helper.fileExists('$sourceDir/file2.log'), isFalse);
      expect(module.deletedFiles, equals(2));
      expect(module.skippedFiles, equals(0));
    });

    test('should handle recursive directory deletion', () async {
      // Arrange
      const sourceDir = '/source/dir';
      const subDir = '$sourceDir/subdir';
      const destDir = '/dest/dir';

      await helper.createDirectory(sourceDir);
      await helper.createDirectory(subDir);
      await helper.createTestFile('$sourceDir/file1.txt', 'content1');
      await helper.createTestFile('$subDir/file2.txt', 'content2');

      final resourceModel = helper.createTestResource(
          source: sourceDir,
          destination: destDir,
          actions: [
            Action(
              type: 'delete',
              properties: {
                'recursive': 'true'
              }
            )
          ]);

      final module = FileDeleteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists('$sourceDir/file1.txt'), isFalse);
      expect(await helper.fileExists('$subDir/file2.txt'), isFalse);
      expect(module.deletedFiles, equals(2));
      expect(module.skippedFiles, equals(0));
    });

    test('should handle non-recursive directory deletion', () async {
      // Arrange
      const sourceDir = '/source/dir';
      const subDir = '$sourceDir/subdir';
      const destDir = '/dest/dir';

      await helper.createDirectory(sourceDir);
      await helper.createDirectory(subDir);
      await helper.createTestFile('$sourceDir/file1.txt', 'content1');
      await helper.createTestFile('$subDir/file2.txt', 'content2');

      final resourceModel = helper.createTestResource(
          source: sourceDir,
          destination: destDir,
          actions: [
            Action(
              type: 'delete',
              properties: {
                'recursive': 'false'
              }
            )
          ]);

      final module = FileDeleteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists('$sourceDir/file1.txt'), isFalse);
      expect(await helper.fileExists('$subDir/file2.txt'), isTrue); // Should remain in subdirectory
      expect(module.deletedFiles, equals(1));
      expect(module.skippedFiles, equals(0));
    });

    test('should handle rollback correctly', () async {
      // Arrange
      const filePath = '/test/file.txt';
      const backupPath = '/test/file.bak';
      const content = 'test content';
      await helper.createTestFile(filePath, content);

      final resourceModel = helper.createTestResource(
          source: filePath,
          destination: '',
          actions: [
            Action(
              type: 'delete',
              properties: {
                'backup': {'backup_path': backupPath}
              }
            )
          ]);

      final module = FileDeleteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();
      await module.rollback();

      // Assert
      expect(await helper.fileExists(filePath), isTrue);
      expect(await helper.fileExists(backupPath), isFalse);
    });

    test('should handle file that does not exist', () async {
      // Arrange
      const filePath = '/nonexistent/file.txt';

      final resourceModel = helper.createTestResource(
          source: filePath,
          destination: '',
          actions: [Action(type: 'delete')]);

      final module = FileDeleteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(module.fileExisted, isFalse);
      expect(module.deletedFiles, equals(0));
    });

    test('should handle complex pattern combinations', () async {
      // Arrange
      const sourceDir = '/source/dir';
      const destDir = '/dest/dir';

      await helper.createDirectory(sourceDir);
      await helper.createTestFile('$sourceDir/important.txt', 'content1');
      await helper.createTestFile('$sourceDir/temp.log', 'content2');
      await helper.createTestFile('$sourceDir/config.json', 'content3');
      await helper.createTestFile('$sourceDir/cache.tmp', 'content4');

      final resourceModel = helper.createTestResource(
          source: sourceDir,
          destination: destDir,
          actions: [
            Action(
              type: 'delete',
              properties: {
                'recursive': 'true',
                'include': '*.txt,*.json',
                'exclude': 'important*'
              }
            )
          ]);

      final module = FileDeleteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists('$sourceDir/important.txt'), isTrue); // Excluded
      expect(await helper.fileExists('$sourceDir/config.json'), isFalse); // Included
      expect(await helper.fileExists('$sourceDir/temp.log'), isTrue); // Not included
      expect(await helper.fileExists('$sourceDir/cache.tmp'), isTrue); // Not included
      expect(module.deletedFiles, equals(1)); // config.json was deleted
      expect(module.skippedFiles, equals(3)); // important.txt, temp.log, cache.tmp were skipped
    });
  });
}
