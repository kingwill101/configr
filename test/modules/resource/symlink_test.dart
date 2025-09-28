import 'package:test/test.dart';
import 'package:configr/modules/resource/symlink.dart';
import 'package:configr/models/action.dart';
import 'package:configr/exceptions.dart';
import '../../helpers/test_helper.dart';

void main() {
  late TestHelper helper;

  setUp(() {
    helper = TestHelper();
  });

  group('Basic Symlink Operations', () {
    test('should create symlink successfully', () async {
      // Arrange
      const sourcePath = 'source/test.txt';
      const linkPath = 'dest/link.txt';
      const content = 'test content';

      await helper.createTestFile(sourcePath, content);

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: linkPath,
          actions: [Action(type: 'symlink')]);

      final module = FileSymlinkModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      final link = helper.fileSystem.link(linkPath);
      expect(await link.exists(), isTrue);
      expect(await link.target(), equals(helper.resolvePath(sourcePath)));
      expect(module.createdSymlinks, equals(1));
      expect(module.createdPaths, contains(helper.resolvePath(linkPath)));
    });

    test('should create destination directory if needed', () async {
      // Arrange
      const sourcePath = 'source/test.txt';
      const linkPath = 'dest/subdir/link.txt';
      const content = 'test content';

      await helper.createTestFile(sourcePath, content);

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: linkPath,
          actions: [Action(type: 'symlink')]);

      final module = FileSymlinkModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      final link = helper.fileSystem.link(linkPath);
      expect(await link.exists(), isTrue);
      expect(module.hadToCreateDstDir, isTrue);
    });

    test('should throw exception when source does not exist', () async {
      // Arrange
      const sourcePath = 'nonexistent/source.txt';
      const linkPath = 'dest/link.txt';

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: linkPath,
          actions: [Action(type: 'symlink')]);

      final module = FileSymlinkModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act & Assert
      expect(() => module(), throwsA(isA<SymlinkCreationException>()));
    });
  });

  group('Conflict Resolution', () {
    test('should skip existing symlink by default', () async {
      // Arrange
      const sourcePath = 'source/test.txt';
      const linkPath = 'dest/link.txt';
      const content = 'test content';

      await helper.createTestFile(sourcePath, content);
      await helper.createTestFile('source/other.txt', 'other content');

      // Create first symlink
      final resourceModel1 = helper.createTestResource(
          source: sourcePath,
          destination: linkPath,
          actions: [Action(type: 'symlink')]);

      final module1 = FileSymlinkModule(resourceModel1, resourceModel1.actions.first,
          fileSystem: helper.fileSystem);
      await module1();

      // Try to create second symlink to same destination
      final resourceModel2 = helper.createTestResource(
          source: 'source/other.txt',
          destination: linkPath,
          actions: [Action(type: 'symlink')]);

      final module2 = FileSymlinkModule(resourceModel2, resourceModel2.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module2();

      // Assert
      final link = helper.fileSystem.link(linkPath);
      expect(await link.exists(), isTrue);
      expect(await link.target(), equals(helper.resolvePath(sourcePath))); // Original target
      expect(module2.skippedSymlinks, equals(1));
      expect(module2.skippedPaths, contains(helper.resolvePath(linkPath)));
    });

    test('should overwrite existing symlink when configured', () async {
      // Arrange
      const sourcePath = 'source/test.txt';
      const linkPath = 'dest/link.txt';
      const content = 'test content';

      await helper.createTestFile(sourcePath, content);
      await helper.createTestFile('source/other.txt', 'other content');

      // Create first symlink
      final resourceModel1 = helper.createTestResource(
          source: sourcePath,
          destination: linkPath,
          actions: [Action(type: 'symlink')]);

      final module1 = FileSymlinkModule(resourceModel1, resourceModel1.actions.first,
          fileSystem: helper.fileSystem);
      await module1();

      // Try to create second symlink with overwrite
      final resourceModel2 = helper.createTestResource(
          source: 'source/other.txt',
          destination: linkPath,
          actions: [Action(type: 'symlink', properties: {'conflict_resolution': 'overwrite'})]);

      final module2 = FileSymlinkModule(resourceModel2, resourceModel2.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module2();

      // Assert
      final link = helper.fileSystem.link(linkPath);
      expect(await link.exists(), isTrue);
      expect(await link.target(), equals(helper.resolvePath('source/other.txt'))); // New target
      expect(module2.overwrittenSymlinks, equals(1));
    });

    test('should throw exception when conflict resolution is error', () async {
      // Arrange
      const sourcePath = 'source/test.txt';
      const linkPath = 'dest/link.txt';
      const content = 'test content';

      await helper.createTestFile(sourcePath, content);
      await helper.createTestFile('source/other.txt', 'other content');

      // Create first symlink
      final resourceModel1 = helper.createTestResource(
          source: sourcePath,
          destination: linkPath,
          actions: [Action(type: 'symlink')]);

      final module1 = FileSymlinkModule(resourceModel1, resourceModel1.actions.first,
          fileSystem: helper.fileSystem);
      await module1();

      // Try to create second symlink with error resolution
      final resourceModel2 = helper.createTestResource(
          source: 'source/other.txt',
          destination: linkPath,
          actions: [Action(type: 'symlink', properties: {'conflict_resolution': 'error'})]);

      final module2 = FileSymlinkModule(resourceModel2, resourceModel2.actions.first,
          fileSystem: helper.fileSystem);

      // Act & Assert
      expect(() => module2(), throwsA(isA<SymlinkCreationException>()));
    });
  });

  group('Bulk Operations', () {
    test('should create symlinks for all files in directory', () async {
      // Arrange - Create directory structure first
      await helper.createTestFile('source/file1.txt', 'content1');
      await helper.createTestFile('source/file2.txt', 'content2');
      await helper.createTestFile('source/subdir/file3.txt', 'content3');

      final resourceModel = helper.createTestResource(
          source: 'source',
          destination: 'dest',
          actions: [Action(type: 'symlink')]);

      final module = FileSymlinkModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(module.totalSymlinks, equals(3));
      expect(module.createdSymlinks, equals(3));
      expect(module.createdPaths, contains(helper.resolvePath('dest/file1.txt')));
      expect(module.createdPaths, contains(helper.resolvePath('dest/file2.txt')));
      expect(module.createdPaths, contains(helper.resolvePath('dest/subdir/file3.txt')));

      // Verify symlinks were created
      final link1 = helper.fileSystem.link('dest/file1.txt');
      final link2 = helper.fileSystem.link('dest/file2.txt');
      final link3 = helper.fileSystem.link('dest/subdir/file3.txt');

      expect(await link1.exists(), isTrue);
      expect(await link2.exists(), isTrue);
      expect(await link3.exists(), isTrue);
    });

    test('should filter files using include patterns', () async {
      // Arrange
      await helper.createTestFile('source/file1.txt', 'content1');
      await helper.createTestFile('source/file2.log', 'content2');
      await helper.createTestFile('source/file3.txt', 'content3');

      final resourceModel = helper.createTestResource(
          source: 'source',
          destination: 'dest',
          actions: [Action(type: 'symlink', properties: {
            'include_patterns': ['*.txt']
          })]);

      final module = FileSymlinkModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(module.totalSymlinks, equals(2));
      expect(module.createdSymlinks, equals(2));
      expect(module.createdPaths, contains(helper.resolvePath('dest/file1.txt')));
      expect(module.createdPaths, contains(helper.resolvePath('dest/file3.txt')));
      expect(module.createdPaths, isNot(contains(helper.resolvePath('dest/file2.log'))));
    });

    test('should exclude files using exclude patterns', () async {
      // Arrange
      await helper.createTestFile('source/file1.txt', 'content1');
      await helper.createTestFile('source/file2.log', 'content2');
      await helper.createTestFile('source/file3.txt', 'content3');

      final resourceModel = helper.createTestResource(
          source: 'source',
          destination: 'dest',
          actions: [Action(type: 'symlink', properties: {
            'exclude_patterns': ['*.log']
          })]);

      final module = FileSymlinkModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(module.totalSymlinks, equals(2));
      expect(module.createdSymlinks, equals(2));
      expect(module.createdPaths, contains(helper.resolvePath('dest/file1.txt')));
      expect(module.createdPaths, contains(helper.resolvePath('dest/file3.txt')));
      expect(module.createdPaths, isNot(contains(helper.resolvePath('dest/file2.log'))));
    });

    test('should combine include and exclude patterns', () async {
      // Arrange
      await helper.createTestFile('source/file1.txt', 'content1');
      await helper.createTestFile('source/file2.log', 'content2');
      await helper.createTestFile('source/file3.txt', 'content3');
      await helper.createTestFile('source/temp.txt', 'content4');

      final resourceModel = helper.createTestResource(
          source: 'source',
          destination: 'dest',
          actions: [Action(type: 'symlink', properties: {
            'include_patterns': ['*.txt'],
            'exclude_patterns': ['temp.*']
          })]);

      final module = FileSymlinkModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(module.totalSymlinks, equals(2));
      expect(module.createdSymlinks, equals(2));
      expect(module.createdPaths, contains(helper.resolvePath('dest/file1.txt')));
      expect(module.createdPaths, contains(helper.resolvePath('dest/file3.txt')));
      expect(module.createdPaths, isNot(contains(helper.resolvePath('dest/file2.log'))));
      expect(module.createdPaths, isNot(contains(helper.resolvePath('dest/temp.txt'))));
    });
  });

  group('Validation', () {
    test('should skip validation when validate_targets is false', () async {
      // Arrange
      const sourcePath = 'nonexistent/source.txt';
      const linkPath = 'dest/link.txt';

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: linkPath,
          actions: [Action(type: 'symlink', properties: {
            'validate_targets': false
          })]);

      final module = FileSymlinkModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      final link = helper.fileSystem.link(linkPath);
      expect(await link.exists(), isTrue);
      expect(module.validateTargets, isFalse);
    });

    test('should not create directories when create_directories is false', () async {
      // Arrange
      const sourcePath = 'source/test.txt';
      const linkPath = 'dest/subdir/link.txt';
      const content = 'test content';

      await helper.createTestFile(sourcePath, content);

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: linkPath,
          actions: [Action(type: 'symlink', properties: {
            'create_directories': false
          })]);

      final module = FileSymlinkModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act & Assert
      expect(() => module(), throwsA(isA<SymlinkCreationException>()));
      expect(module.createDirectories, isFalse);
    });
  });

  group('Rollback Operations', () {
    test('should rollback single symlink creation', () async {
      // Arrange
      const sourcePath = 'source/test.txt';
      const linkPath = 'dest/link.txt';
      const content = 'test content';

      await helper.createTestFile(sourcePath, content);

      final resourceModel = helper.createTestResource(
          source: sourcePath,
          destination: linkPath,
          actions: [Action(type: 'symlink')]);

      final module = FileSymlinkModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();
      await module.rollback();

      // Assert
      final link = helper.fileSystem.link(linkPath);
      expect(await link.exists(), isFalse);
      expect(module.rollbackCompleted, isTrue);
    });

    test('should rollback bulk symlink creation', () async {
      // Arrange
      await helper.createTestFile('source/file1.txt', 'content1');
      await helper.createTestFile('source/file2.txt', 'content2');

      final resourceModel = helper.createTestResource(
          source: 'source',
          destination: 'dest',
          actions: [Action(type: 'symlink')]);

      final module = FileSymlinkModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();
      await module.rollback();

      // Assert
      final link1 = helper.fileSystem.link('dest/file1.txt');
      final link2 = helper.fileSystem.link('dest/file2.txt');
      expect(await link1.exists(), isFalse);
      expect(await link2.exists(), isFalse);
    });

    test('should restore original symlink on rollback', () async {
      // Arrange
      const sourcePath = 'source/test.txt';
      const linkPath = 'dest/link.txt';
      const content = 'test content';

      await helper.createTestFile(sourcePath, content);
      await helper.createTestFile('source/other.txt', 'other content');

      // Create original symlink
      final resourceModel1 = helper.createTestResource(
          source: sourcePath,
          destination: linkPath,
          actions: [Action(type: 'symlink')]);

      final module1 = FileSymlinkModule(resourceModel1, resourceModel1.actions.first,
          fileSystem: helper.fileSystem);
      await module1();

      // Overwrite with new symlink
      final resourceModel2 = helper.createTestResource(
          source: 'source/other.txt',
          destination: linkPath,
          actions: [Action(type: 'symlink', properties: {'conflict_resolution': 'overwrite'})]);

      final module2 = FileSymlinkModule(resourceModel2, resourceModel2.actions.first,
          fileSystem: helper.fileSystem);
      await module2();
      await module2.rollback();

      // Assert
      final link = helper.fileSystem.link(linkPath);
      expect(await link.exists(), isTrue);
      expect(await link.target(), equals(helper.resolvePath(sourcePath))); // Original target restored
    });
  });

  group('Progress Tracking', () {
    test('should track progress for bulk operations', () async {
      // Arrange
      await helper.createTestFile('source/file1.txt', 'content1');
      await helper.createTestFile('source/file2.txt', 'content2');
      await helper.createTestFile('source/file3.txt', 'content3');

      final resourceModel = helper.createTestResource(
          source: 'source',
          destination: 'dest',
          actions: [Action(type: 'symlink', properties: {
            'show_progress': true
          })]);

      final module = FileSymlinkModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(module.showProgress, isTrue);
      expect(module.totalSymlinks, equals(3));
      expect(module.createdSymlinks, equals(3));
    });
  });
}
