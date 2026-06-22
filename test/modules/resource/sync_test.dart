import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:configr/src/models/action.dart';
import 'package:configr/src/models/file_model.dart';
import 'package:configr/src/modules/resource/sync.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';
void main() {
  group('FileSyncModule', () {
    late Directory tempDir;
    late Directory sourceDir;
    late Directory destDir;
    late FileSyncModule syncModule;
    late FileSystem fileSystem;

    setUp(() async {
      fileSystem = MemoryFileSystem();
      tempDir = fileSystem.systemTempDirectory.createTempSync();
      sourceDir = fileSystem.directory(path.join(tempDir.path, 'source'));
      destDir = fileSystem.directory(path.join(tempDir.path, 'destination'));
      
      sourceDir.createSync(recursive: true);
      destDir.createSync(recursive: true);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('should initialize with default values', () {
      final action = Action(
        id: 'test-sync',
        type: 'sync',
        properties: {},
      );
      final resource = ResourceModel(
        id: 'test-resource',
        source: sourceDir.path,
        destination: destDir.path,
        type: 'sync',
        actions: [],
      );

      syncModule = FileSyncModule(resource, action, fileSystem: fileSystem);

      expect(syncModule.syncMode, equals('bidirectional'));
      expect(syncModule.conflictResolution, equals('newer'));
      expect(syncModule.bandwidthLimit, equals(0));
      expect(syncModule.preservePermissions, isTrue);
      expect(syncModule.preserveTimestamps, isTrue);
      expect(syncModule.deleteOrphans, isFalse);
      expect(syncModule.excludePatterns, isEmpty);
      expect(syncModule.includePatterns, isEmpty);
      expect(syncModule.syncId, equals(0));
      expect(syncModule.syncResults, isEmpty);
      expect(syncModule.filesProcessed, equals(0));
      expect(syncModule.conflictsResolved, equals(0));
      expect(syncModule.errorsEncountered, equals(0));
    });

    test('should load configuration from action properties', () {
      final action = Action(
        id: 'test-sync',
        type: 'sync',
        properties: {
          'sync_mode': 'source_to_dest',
          'conflict_resolution': 'source',
          'bandwidth_limit': 1024,
          'preserve_permissions': false,
          'preserve_timestamps': false,
          'delete_orphans': true,
          'exclude_patterns': ['*.tmp', '*.log'],
          'include_patterns': ['*.txt', '*.md'],
        },
      );
      final resource = ResourceModel(
        id: 'test-resource',
        source: sourceDir.path,
        destination: destDir.path,
        type: 'sync',
        actions: [],
      );

      syncModule = FileSyncModule(resource, action, fileSystem: fileSystem);

      expect(syncModule.syncMode, equals('source_to_dest'));
      expect(syncModule.conflictResolution, equals('source'));
      expect(syncModule.bandwidthLimit, equals(1024));
      expect(syncModule.preservePermissions, isFalse);
      expect(syncModule.preserveTimestamps, isFalse);
      expect(syncModule.deleteOrphans, isTrue);
      expect(syncModule.excludePatterns, equals(['*.tmp', '*.log']));
      expect(syncModule.includePatterns, equals(['*.txt', '*.md']));
    });

    test('should perform bidirectional sync successfully', () async {
      // Create test files
        final sourceFile1 = fileSystem.file(path.join(sourceDir.path, 'file1.txt'));
        final sourceFile2 = fileSystem.file(path.join(sourceDir.path, 'subdir', 'file2.txt'));
      sourceFile1.writeAsStringSync('content1');
      sourceFile2.parent.createSync(recursive: true);
      sourceFile2.writeAsStringSync('content2');

      final action = Action(
        id: 'test-sync',
        type: 'sync',
        properties: {
          'sync_mode': 'bidirectional',
        },
      );
      final resource = ResourceModel(
        id: 'test-resource',
        source: sourceDir.path,
        destination: destDir.path,
        type: 'sync',
        actions: [],
      );

      syncModule = FileSyncModule(resource, action, fileSystem: fileSystem);

      await syncModule.execute();

      expect(syncModule.filesProcessed, greaterThan(0));
      expect(syncModule.syncResults, isNotEmpty);
      expect(syncModule.errorsEncountered, equals(0));

      // Verify files were synced
        final destFile1 = fileSystem.file(path.join(destDir.path, 'file1.txt'));
        final destFile2 = fileSystem.file(path.join(destDir.path, 'subdir', 'file2.txt'));
      expect(destFile1.existsSync(), isTrue);
      expect(destFile2.existsSync(), isTrue);
      expect(destFile1.readAsStringSync(), equals('content1'));
      expect(destFile2.readAsStringSync(), equals('content2'));
    });

    test('should perform source to destination sync', () async {
      // Create test files
        final sourceFile = fileSystem.file(path.join(sourceDir.path, 'test.txt'));
      sourceFile.writeAsStringSync('test content');

      final action = Action(
        id: 'test-sync',
        type: 'sync',
        properties: {
          'sync_mode': 'source_to_dest',
        },
      );
      final resource = ResourceModel(
        id: 'test-resource',
        source: sourceDir.path,
        destination: destDir.path,
        type: 'sync',
        actions: [],
      );

      syncModule = FileSyncModule(resource, action, fileSystem: fileSystem);

      await syncModule.execute();

      expect(syncModule.filesProcessed, greaterThan(0));
      expect(syncModule.errorsEncountered, equals(0));

      // Verify file was synced
        final destFile = fileSystem.file(path.join(destDir.path, 'test.txt'));
      expect(destFile.existsSync(), isTrue);
      expect(destFile.readAsStringSync(), equals('test content'));
    });

    test('should handle conflict resolution with newer strategy', () async {
      // Create source file
        final sourceFile = fileSystem.file(path.join(sourceDir.path, 'conflict.txt'));
      sourceFile.writeAsStringSync('newer content');
      
      // Create older destination file
        final destFile = fileSystem.file(path.join(destDir.path, 'conflict.txt'));
      destFile.writeAsStringSync('older content');
      final oldTime = DateTime.now().subtract(Duration(hours: 1));
      destFile.setLastModifiedSync(oldTime);

      final action = Action(
        id: 'test-sync',
        type: 'sync',
        properties: {
          'sync_mode': 'source_to_dest',
          'conflict_resolution': 'newer',
        },
      );
      final resource = ResourceModel(
        id: 'test-resource',
        source: sourceDir.path,
        destination: destDir.path,
        type: 'sync',
        actions: [],
      );

      syncModule = FileSyncModule(resource, action, fileSystem: fileSystem);

      await syncModule.execute();

      expect(syncModule.conflictsResolved, greaterThan(0));
      expect(destFile.readAsStringSync(), equals('newer content'));
    });

    test('should handle conflict resolution with source strategy', () async {
      // Create source file
        final sourceFile = fileSystem.file(path.join(sourceDir.path, 'conflict.txt'));
      sourceFile.writeAsStringSync('source content');
      
      // Create destination file
        final destFile = fileSystem.file(path.join(destDir.path, 'conflict.txt'));
      destFile.writeAsStringSync('dest content');

      final action = Action(
        id: 'test-sync',
        type: 'sync',
        properties: {
          'sync_mode': 'source_to_dest',
          'conflict_resolution': 'source',
        },
      );
      final resource = ResourceModel(
        id: 'test-resource',
        source: sourceDir.path,
        destination: destDir.path,
        type: 'sync',
        actions: [],
      );

      syncModule = FileSyncModule(resource, action, fileSystem: fileSystem);

      await syncModule.execute();

      expect(syncModule.conflictsResolved, greaterThan(0));
      expect(destFile.readAsStringSync(), equals('source content'));
    });

    test('should handle conflict resolution with destination strategy', () async {
      // Create source file
        final sourceFile = fileSystem.file(path.join(sourceDir.path, 'conflict.txt'));
      sourceFile.writeAsStringSync('source content');
      
      // Create destination file
        final destFile = fileSystem.file(path.join(destDir.path, 'conflict.txt'));
      destFile.writeAsStringSync('dest content');

      final action = Action(
        id: 'test-sync',
        type: 'sync',
        properties: {
          'sync_mode': 'source_to_dest',
          'conflict_resolution': 'destination',
        },
      );
      final resource = ResourceModel(
        id: 'test-resource',
        source: sourceDir.path,
        destination: destDir.path,
        type: 'sync',
        actions: [],
      );

      syncModule = FileSyncModule(resource, action, fileSystem: fileSystem);

      await syncModule.execute();

      expect(destFile.readAsStringSync(), equals('dest content'));
    });

    test('should exclude files based on exclude patterns', () async {
      // Create test files
        final sourceFile1 = fileSystem.file(path.join(sourceDir.path, 'include.txt'));
        final sourceFile2 = fileSystem.file(path.join(sourceDir.path, 'exclude.tmp'));
      sourceFile1.writeAsStringSync('include content');
      sourceFile2.writeAsStringSync('exclude content');

      final action = Action(
        id: 'test-sync',
        type: 'sync',
        properties: {
          'sync_mode': 'source_to_dest',
          'exclude_patterns': ['*.tmp'],
        },
      );
      final resource = ResourceModel(
        id: 'test-resource',
        source: sourceDir.path,
        destination: destDir.path,
        type: 'sync',
        actions: [],
      );

      syncModule = FileSyncModule(resource, action, fileSystem: fileSystem);

      await syncModule.execute();

      // Verify only included file was synced
        final destFile1 = fileSystem.file(path.join(destDir.path, 'include.txt'));
        final destFile2 = fileSystem.file(path.join(destDir.path, 'exclude.tmp'));
      expect(destFile1.existsSync(), isTrue);
      expect(destFile2.existsSync(), isFalse);
    });

    test('should include only files matching include patterns', () async {
      // Create test files
        final sourceFile1 = fileSystem.file(path.join(sourceDir.path, 'include.txt'));
        final sourceFile2 = fileSystem.file(path.join(sourceDir.path, 'exclude.doc'));
      sourceFile1.writeAsStringSync('include content');
      sourceFile2.writeAsStringSync('exclude content');

      final action = Action(
        id: 'test-sync',
        type: 'sync',
        properties: {
          'sync_mode': 'source_to_dest',
          'include_patterns': ['*.txt'],
        },
      );
      final resource = ResourceModel(
        id: 'test-resource',
        source: sourceDir.path,
        destination: destDir.path,
        type: 'sync',
        actions: [],
      );

      syncModule = FileSyncModule(resource, action, fileSystem: fileSystem);

      await syncModule.execute();

      // Verify only included file was synced
        final destFile1 = fileSystem.file(path.join(destDir.path, 'include.txt'));
        final destFile2 = fileSystem.file(path.join(destDir.path, 'exclude.doc'));
      expect(destFile1.existsSync(), isTrue);
      expect(destFile2.existsSync(), isFalse);
    });

    test('should delete orphaned files when deleteOrphans is enabled', () async {
      // Create destination file that doesn't exist in source
        final orphanFile = fileSystem.file(path.join(destDir.path, 'orphan.txt'));
      orphanFile.writeAsStringSync('orphan content');

      final action = Action(
        id: 'test-sync',
        type: 'sync',
        properties: {
          'sync_mode': 'source_to_dest',
          'delete_orphans': true,
        },
      );
      final resource = ResourceModel(
        id: 'test-resource',
        source: sourceDir.path,
        destination: destDir.path,
        type: 'sync',
        actions: [],
      );

      syncModule = FileSyncModule(resource, action, fileSystem: fileSystem);

      await syncModule.execute();

      // Verify orphaned file was deleted
      expect(orphanFile.existsSync(), isFalse);
    });

    test('should handle missing source path', () async {
      final action = Action(
        id: 'test-sync',
        type: 'sync',
        properties: {},
      );
      final resource = ResourceModel(
        id: 'test-resource',
        source: '/nonexistent/path',
        destination: destDir.path,
        type: 'sync',
        actions: [],
      );

      syncModule = FileSyncModule(resource, action, fileSystem: fileSystem);

      expect(
        () => syncModule.execute(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Source path does not exist'),
        )),
      );
    });

    test('should create destination directory if it does not exist', () async {
        final newDestDir = fileSystem.directory(path.join(tempDir.path, 'new_destination'));
        final sourceFile = fileSystem.file(path.join(sourceDir.path, 'test.txt'));
      sourceFile.writeAsStringSync('test content');

      final action = Action(
        id: 'test-sync',
        type: 'sync',
        properties: {
          'sync_mode': 'source_to_dest',
        },
      );
      final resource = ResourceModel(
        id: 'test-resource',
        source: sourceDir.path,
        destination: newDestDir.path,
        type: 'sync',
        actions: [],
      );

      syncModule = FileSyncModule(resource, action, fileSystem: fileSystem);

      await syncModule.execute();

      expect(newDestDir.existsSync(), isTrue);
        final destFile = fileSystem.file(path.join(newDestDir.path, 'test.txt'));
      expect(destFile.existsSync(), isTrue);
    });

    test('should handle invalid sync mode', () async {
      final action = Action(
        id: 'test-sync',
        type: 'sync',
        properties: {
          'sync_mode': 'invalid_mode',
        },
      );
      final resource = ResourceModel(
        id: 'test-resource',
        source: sourceDir.path,
        destination: destDir.path,
        type: 'sync',
        actions: [],
      );

      syncModule = FileSyncModule(resource, action, fileSystem: fileSystem);

      expect(
        () => syncModule.execute(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Invalid sync mode'),
        )),
      );
    });

    test('should perform rollback successfully', () async {
      final action = Action(
        id: 'test-sync',
        type: 'sync',
        properties: {},
      );
      final resource = ResourceModel(
        id: 'test-resource',
        source: sourceDir.path,
        destination: destDir.path,
        type: 'sync',
        actions: [],
      );

      syncModule = FileSyncModule(resource, action, fileSystem: fileSystem);

      // Rollback should not throw
      await expectLater(syncModule.rollback(), completes);
    });

    test('should track sync statistics correctly', () async {
      // Create test files
        final sourceFile1 = fileSystem.file(path.join(sourceDir.path, 'file1.txt'));
        final sourceFile2 = fileSystem.file(path.join(sourceDir.path, 'file2.txt'));
      sourceFile1.writeAsStringSync('content1');
      sourceFile2.writeAsStringSync('content2');

      final action = Action(
        id: 'test-sync',
        type: 'sync',
        properties: {
          'sync_mode': 'source_to_dest',
        },
      );
      final resource = ResourceModel(
        id: 'test-resource',
        source: sourceDir.path,
        destination: destDir.path,
        type: 'sync',
        actions: [],
      );

      syncModule = FileSyncModule(resource, action, fileSystem: fileSystem);

      await syncModule.execute();

      expect(syncModule.filesProcessed, equals(2));
      expect(syncModule.syncResults.length, equals(2));
      expect(syncModule.errorsEncountered, equals(0));
      expect(syncModule.syncId, greaterThan(0));
    });
  });
}
