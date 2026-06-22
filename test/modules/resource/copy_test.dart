import 'package:test/test.dart';
import 'package:configr/src/modules/resource/copy.dart';
import 'package:configr/src/models/action.dart';
import 'package:configr/src/utils/file_utils.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/utils/event_bus.dart';
import '../../helpers/test_helper.dart';

void main() {
  late TestHelper helper;

  setUp(() {
    helper = TestHelper();
  });

  test('should copy file successfully', () async {
    // Arrange
    const sourceDir = '/source/dir';
    const destDir = '/dest/dir';

    const destinationFile = "$destDir/file1.txt";
    const sourceFile = "$sourceDir/file1.txt";
    const content = 'content1';

    await FileUtils.createDirectory(sourceDir, fileSystem: helper.fileSystem);
    await FileUtils.writeFile(
      sourceFile,
      content,
      fileSystem: helper.fileSystem,
    );

    final resourceModel = helper.createTestResource(
      source: sourceFile,
      destination: destinationFile,
      actions: [Action(type: 'copy')],
    );

    final module = FileCopyModule(
      resourceModel,
      resourceModel.actions.first,
      fileSystem: helper.fileSystem,
    );

    // Act
    await module();

    // Assert
    expect(
      await FileUtils.fileExists(
        destinationFile,
        fileSystem: helper.fileSystem,
      ),
      isTrue,
    );
    expect(
      await FileUtils.readFile(destinationFile, fileSystem: helper.fileSystem),
      equals(content),
    );
  });

  test('should handle directory copy', () async {
    // Arrange
    const sourceDir = '/source/dir';
    const destDir = '/dest/dir';

    await FileUtils.createDirectory(sourceDir, fileSystem: helper.fileSystem);
    await FileUtils.writeFile(
      '$sourceDir/file1.txt',
      'content1',
      fileSystem: helper.fileSystem,
    );
    await FileUtils.writeFile(
      '$sourceDir/file2.txt',
      'content2',
      fileSystem: helper.fileSystem,
    );

    final resourceModel = helper.createTestResource(
      source: sourceDir,
      destination: destDir,
      actions: [
        Action(type: 'copy', properties: {'recursive': 'true'}),
      ],
    );

    final module = FileCopyModule(
      resourceModel,
      resourceModel.actions.first,
      fileSystem: helper.fileSystem,
    );

    // Act
    await module();

    // Assert
    expect(
      await FileUtils.directoryExists(destDir, fileSystem: helper.fileSystem),
      isTrue,
    );
    expect(
      await FileUtils.readFile(
        '$destDir/file1.txt',
        fileSystem: helper.fileSystem,
      ),
      equals('content1'),
    );
    expect(
      await FileUtils.readFile(
        '$destDir/file2.txt',
        fileSystem: helper.fileSystem,
      ),
      equals('content2'),
    );
  });

  test('should handle rollback correctly', () async {
    const sourceDir = '/source/dir';
    const destDir = '/dest/dir';

    const destinationFile = "$destDir/file1.txt";
    const sourceFile = "$sourceDir/file1.txt";

    await FileUtils.createDirectory(sourceDir, fileSystem: helper.fileSystem);
    await FileUtils.writeFile(
      sourceFile,
      'content1',
      fileSystem: helper.fileSystem,
    );

    final resourceModel = helper.createTestResource(
      source: sourceFile,
      destination: destinationFile,
      actions: [Action(type: 'copy')],
    );

    final module = FileCopyModule(
      resourceModel,
      resourceModel.actions.first,
      fileSystem: helper.fileSystem,
    );

    // Act
    await module();
    await module.rollback();

    // Assert
    expect(
      await FileUtils.fileExists(
        destinationFile,
        fileSystem: helper.fileSystem,
      ),
      isFalse,
    );
  });

  test('should fail when source does not exist', () async {
    // Arrange
    const sourcePath = '/nonexistent/file.txt';
    const destPath = '/dest/file.txt';

    final resourceModel = helper.createTestResource(
      source: sourcePath,
      destination: destPath,
      actions: [Action(type: 'copy')],
    );

    final module = FileCopyModule(
      resourceModel,
      resourceModel.actions.first,
      fileSystem: helper.fileSystem,
    );

    // Act & Assert
    expect(() async => await module(), throwsException);
  });

  test('should copy files with include patterns', () async {
    // Arrange
    const sourceDir = '/source/dir';
    const destDir = '/dest/dir';

    await FileUtils.createDirectory(sourceDir, fileSystem: helper.fileSystem);
    await FileUtils.writeFile(
      '$sourceDir/file1.txt',
      'content1',
      fileSystem: helper.fileSystem,
    );
    await FileUtils.writeFile(
      '$sourceDir/file2.log',
      'content2',
      fileSystem: helper.fileSystem,
    );
    await FileUtils.writeFile(
      '$sourceDir/file3.txt',
      'content3',
      fileSystem: helper.fileSystem,
    );

    final resourceModel = helper.createTestResource(
      source: sourceDir,
      destination: destDir,
      actions: [
        Action(
          type: 'copy',
          properties: {'recursive': 'true', 'include': '*.txt'},
        ),
      ],
    );

    final module = FileCopyModule(
      resourceModel,
      resourceModel.actions.first,
      fileSystem: helper.fileSystem,
    );

    // Act
    await module();

    // Assert
    expect(
      await FileUtils.fileExists(
        '$destDir/file1.txt',
        fileSystem: helper.fileSystem,
      ),
      isTrue,
    );
    expect(
      await FileUtils.fileExists(
        '$destDir/file3.txt',
        fileSystem: helper.fileSystem,
      ),
      isTrue,
    );
    expect(
      await FileUtils.fileExists(
        '$destDir/file2.log',
        fileSystem: helper.fileSystem,
      ),
      isFalse,
    ); // Should be excluded
    expect(module.copiedFiles, equals(2));
    expect(module.skippedFiles, equals(1));
  });

  test('should copy files with exclude patterns', () async {
    // Arrange
    const sourceDir = '/source/dir';
    const destDir = '/dest/dir';

    await FileUtils.createDirectory(sourceDir, fileSystem: helper.fileSystem);
    await FileUtils.writeFile(
      '$sourceDir/file1.txt',
      'content1',
      fileSystem: helper.fileSystem,
    );
    await FileUtils.writeFile(
      '$sourceDir/file2.log',
      'content2',
      fileSystem: helper.fileSystem,
    );
    await FileUtils.writeFile(
      '$sourceDir/file3.txt',
      'content3',
      fileSystem: helper.fileSystem,
    );

    final resourceModel = helper.createTestResource(
      source: sourceDir,
      destination: destDir,
      actions: [
        Action(
          type: 'copy',
          properties: {'recursive': 'true', 'exclude': '*.log'},
        ),
      ],
    );

    final module = FileCopyModule(
      resourceModel,
      resourceModel.actions.first,
      fileSystem: helper.fileSystem,
    );

    // Act
    await module();

    // Assert
    expect(
      await FileUtils.fileExists(
        '$destDir/file1.txt',
        fileSystem: helper.fileSystem,
      ),
      isTrue,
    );
    expect(
      await FileUtils.fileExists(
        '$destDir/file3.txt',
        fileSystem: helper.fileSystem,
      ),
      isTrue,
    );
    expect(
      await FileUtils.fileExists(
        '$destDir/file2.log',
        fileSystem: helper.fileSystem,
      ),
      isFalse,
    ); // Should be excluded
    expect(module.copiedFiles, equals(2));
    expect(module.skippedFiles, equals(1));
  });

  test('should handle conflict resolution - skip', () async {
    // Arrange
    const sourceFile = '/source/file.txt';
    const destFile = '/dest/file.txt';

    await FileUtils.createDirectory('/source', fileSystem: helper.fileSystem);
    await FileUtils.createDirectory('/dest', fileSystem: helper.fileSystem);
    await FileUtils.writeFile(
      sourceFile,
      'new content',
      fileSystem: helper.fileSystem,
    );
    await FileUtils.writeFile(
      destFile,
      'existing content',
      fileSystem: helper.fileSystem,
    );

    final resourceModel = helper.createTestResource(
      source: sourceFile,
      destination: destFile,
      actions: [
        Action(type: 'copy', properties: {'conflict_resolution': 'skip'}),
      ],
    );

    final module = FileCopyModule(
      resourceModel,
      resourceModel.actions.first,
      fileSystem: helper.fileSystem,
    );

    // Act
    await module();

    // Assert
    expect(
      await FileUtils.readFile(destFile, fileSystem: helper.fileSystem),
      equals('existing content'),
    ); // Should remain unchanged
    expect(module.copiedFiles, equals(0));
    expect(module.skippedFiles, equals(1));
  });

  test('should handle conflict resolution - overwrite', () async {
    // Arrange
    const sourceFile = '/source/file.txt';
    const destFile = '/dest/file.txt';

    await FileUtils.createDirectory('/source', fileSystem: helper.fileSystem);
    await FileUtils.createDirectory('/dest', fileSystem: helper.fileSystem);
    await FileUtils.writeFile(
      sourceFile,
      'new content',
      fileSystem: helper.fileSystem,
    );
    await FileUtils.writeFile(
      destFile,
      'existing content',
      fileSystem: helper.fileSystem,
    );

    final resourceModel = helper.createTestResource(
      source: sourceFile,
      destination: destFile,
      actions: [
        Action(type: 'copy', properties: {'conflict_resolution': 'overwrite'}),
      ],
    );

    final module = FileCopyModule(
      resourceModel,
      resourceModel.actions.first,
      fileSystem: helper.fileSystem,
    );

    // Act
    await module();

    // Assert
    expect(
      await FileUtils.readFile(destFile, fileSystem: helper.fileSystem),
      equals('new content'),
    ); // Should be overwritten
    expect(module.copiedFiles, equals(1));
    expect(module.overwrittenFiles, equals(1));
  });

  test('should track progress for directory copy', () async {
    // Arrange
    const sourceDir = '/source/dir';
    const destDir = '/dest/dir';

    await FileUtils.createDirectory(sourceDir, fileSystem: helper.fileSystem);
    await FileUtils.writeFile(
      '$sourceDir/file1.txt',
      'content1',
      fileSystem: helper.fileSystem,
    );
    await FileUtils.writeFile(
      '$sourceDir/file2.txt',
      'content2',
      fileSystem: helper.fileSystem,
    );
    await FileUtils.writeFile(
      '$sourceDir/file3.txt',
      'content3',
      fileSystem: helper.fileSystem,
    );

    final resourceModel = helper.createTestResource(
      source: sourceDir,
      destination: destDir,
      actions: [
        Action(
          type: 'copy',
          properties: {'recursive': 'true', 'show_progress': 'true'},
        ),
      ],
    );

    final module = FileCopyModule(
      resourceModel,
      resourceModel.actions.first,
      fileSystem: helper.fileSystem,
    );

    // Act
    await module();

    // Assert
    expect(module.totalFiles, equals(3));
    expect(module.copiedFiles, equals(3));
    expect(module.skippedFiles, equals(0));
  });

  test('should handle multiple include patterns', () async {
    // Arrange
    const sourceDir = '/source/dir';
    const destDir = '/dest/dir';

    await FileUtils.createDirectory(sourceDir, fileSystem: helper.fileSystem);
    await FileUtils.writeFile(
      '$sourceDir/file1.txt',
      'content1',
      fileSystem: helper.fileSystem,
    );
    await FileUtils.writeFile(
      '$sourceDir/file2.log',
      'content2',
      fileSystem: helper.fileSystem,
    );
    await FileUtils.writeFile(
      '$sourceDir/file3.md',
      'content3',
      fileSystem: helper.fileSystem,
    );
    await FileUtils.writeFile(
      '$sourceDir/file4.dat',
      'content4',
      fileSystem: helper.fileSystem,
    );

    final resourceModel = helper.createTestResource(
      source: sourceDir,
      destination: destDir,
      actions: [
        Action(
          type: 'copy',
          properties: {'recursive': 'true', 'include': '*.txt,*.md'},
        ),
      ],
    );

    final module = FileCopyModule(
      resourceModel,
      resourceModel.actions.first,
      fileSystem: helper.fileSystem,
    );

    // Act
    await module();

    // Assert
    expect(
      await FileUtils.fileExists(
        '$destDir/file1.txt',
        fileSystem: helper.fileSystem,
      ),
      isTrue,
    );
    expect(
      await FileUtils.fileExists(
        '$destDir/file3.md',
        fileSystem: helper.fileSystem,
      ),
      isTrue,
    );
    expect(
      await FileUtils.fileExists(
        '$destDir/file2.log',
        fileSystem: helper.fileSystem,
      ),
      isFalse,
    );
    expect(
      await FileUtils.fileExists(
        '$destDir/file4.dat',
        fileSystem: helper.fileSystem,
      ),
      isFalse,
    );
    expect(module.copiedFiles, equals(2));
    expect(module.skippedFiles, equals(2));
  });

  test('should handle multiple exclude patterns', () async {
    // Arrange
    const sourceDir = '/source/dir';
    const destDir = '/dest/dir';

    await FileUtils.createDirectory(sourceDir, fileSystem: helper.fileSystem);
    await FileUtils.writeFile(
      '$sourceDir/file1.txt',
      'content1',
      fileSystem: helper.fileSystem,
    );
    await FileUtils.writeFile(
      '$sourceDir/file2.log',
      'content2',
      fileSystem: helper.fileSystem,
    );
    await FileUtils.writeFile(
      '$sourceDir/file3.tmp',
      'content3',
      fileSystem: helper.fileSystem,
    );
    await FileUtils.writeFile(
      '$sourceDir/file4.md',
      'content4',
      fileSystem: helper.fileSystem,
    );

    final resourceModel = helper.createTestResource(
      source: sourceDir,
      destination: destDir,
      actions: [
        Action(
          type: 'copy',
          properties: {'recursive': 'true', 'exclude': '*.log,*.tmp'},
        ),
      ],
    );

    final module = FileCopyModule(
      resourceModel,
      resourceModel.actions.first,
      fileSystem: helper.fileSystem,
    );

    // Act
    await module();

    // Assert
    expect(
      await FileUtils.fileExists(
        '$destDir/file1.txt',
        fileSystem: helper.fileSystem,
      ),
      isTrue,
    );
    expect(
      await FileUtils.fileExists(
        '$destDir/file4.md',
        fileSystem: helper.fileSystem,
      ),
      isTrue,
    );
    expect(
      await FileUtils.fileExists(
        '$destDir/file2.log',
        fileSystem: helper.fileSystem,
      ),
      isFalse,
    );
    expect(
      await FileUtils.fileExists(
        '$destDir/file3.tmp',
        fileSystem: helper.fileSystem,
      ),
      isFalse,
    );
    expect(module.copiedFiles, equals(2));
    expect(module.skippedFiles, equals(2));
  });

  test('should emit progress events during directory copy', () async {
    // Arrange
    const sourceDir = '/source/dir';
    const destDir = '/dest/dir';

    await FileUtils.createDirectory(sourceDir, fileSystem: helper.fileSystem);
    await FileUtils.writeFile(
      '$sourceDir/file1.txt',
      'content1',
      fileSystem: helper.fileSystem,
    );
    await FileUtils.writeFile(
      '$sourceDir/file2.txt',
      'content2',
      fileSystem: helper.fileSystem,
    );

    final resourceModel = helper.createTestResource(
      source: sourceDir,
      destination: destDir,
      actions: [
        Action(
          type: 'copy',
          properties: {'recursive': 'true', 'show_progress': 'true'},
        ),
      ],
    );

    final module = FileCopyModule(
      resourceModel,
      resourceModel.actions.first,
      fileSystem: helper.fileSystem,
    );

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

    await FileUtils.createDirectory(sourceDir, fileSystem: helper.fileSystem);
    await FileUtils.writeFile(
      '$sourceDir/test1.txt',
      'content1',
      fileSystem: helper.fileSystem,
    );
    await FileUtils.writeFile(
      '$sourceDir/test2.log',
      'content2',
      fileSystem: helper.fileSystem,
    );
    await FileUtils.writeFile(
      '$sourceDir/other.txt',
      'content3',
      fileSystem: helper.fileSystem,
    );

    final resourceModel = helper.createTestResource(
      source: sourceDir,
      destination: destDir,
      actions: [
        Action(
          type: 'copy',
          properties: {'recursive': 'true', 'include': 'test*'},
        ),
      ],
    );

    final module = FileCopyModule(
      resourceModel,
      resourceModel.actions.first,
      fileSystem: helper.fileSystem,
    );

    // Act
    await module();

    // Assert
    expect(
      await FileUtils.fileExists(
        '$destDir/test1.txt',
        fileSystem: helper.fileSystem,
      ),
      isTrue,
    );
    expect(
      await FileUtils.fileExists(
        '$destDir/test2.log',
        fileSystem: helper.fileSystem,
      ),
      isTrue,
    );
    expect(
      await FileUtils.fileExists(
        '$destDir/other.txt',
        fileSystem: helper.fileSystem,
      ),
      isFalse,
    );
    expect(module.copiedFiles, equals(2));
    expect(module.skippedFiles, equals(1));
  });

  test('should handle empty include patterns (copy all)', () async {
    // Arrange
    const sourceDir = '/source/dir';
    const destDir = '/dest/dir';

    await FileUtils.createDirectory(sourceDir, fileSystem: helper.fileSystem);
    await FileUtils.writeFile(
      '$sourceDir/file1.txt',
      'content1',
      fileSystem: helper.fileSystem,
    );
    await FileUtils.writeFile(
      '$sourceDir/file2.log',
      'content2',
      fileSystem: helper.fileSystem,
    );

    final resourceModel = helper.createTestResource(
      source: sourceDir,
      destination: destDir,
      actions: [
        Action(
          type: 'copy',
          properties: {
            'recursive': 'true',
            // No include patterns - should copy all
          },
        ),
      ],
    );

    final module = FileCopyModule(
      resourceModel,
      resourceModel.actions.first,
      fileSystem: helper.fileSystem,
    );

    // Act
    await module();

    // Assert
    expect(
      await FileUtils.fileExists(
        '$destDir/file1.txt',
        fileSystem: helper.fileSystem,
      ),
      isTrue,
    );
    expect(
      await FileUtils.fileExists(
        '$destDir/file2.log',
        fileSystem: helper.fileSystem,
      ),
      isTrue,
    );
    expect(module.copiedFiles, equals(2));
    expect(module.skippedFiles, equals(0));
  });

  test(
    'should handle conflict resolution - merge (treated as overwrite)',
    () async {
      // Arrange
      const sourceFile = '/source/file.txt';
      const destFile = '/dest/file.txt';

      await FileUtils.createDirectory('/source', fileSystem: helper.fileSystem);
      await FileUtils.createDirectory('/dest', fileSystem: helper.fileSystem);
      await FileUtils.writeFile(
        sourceFile,
        'new content',
        fileSystem: helper.fileSystem,
      );
      await FileUtils.writeFile(
        destFile,
        'existing content',
        fileSystem: helper.fileSystem,
      );

      final resourceModel = helper.createTestResource(
        source: sourceFile,
        destination: destFile,
        actions: [
          Action(type: 'copy', properties: {'conflict_resolution': 'merge'}),
        ],
      );

      final module = FileCopyModule(
        resourceModel,
        resourceModel.actions.first,
        fileSystem: helper.fileSystem,
      );

      // Act
      await module();

      // Assert
      expect(
        await FileUtils.readFile(destFile, fileSystem: helper.fileSystem),
        equals('new content'),
      ); // Should be overwritten (merge treated as overwrite)
      expect(module.copiedFiles, equals(1));
      expect(module.overwrittenFiles, equals(1));
    },
  );
}
