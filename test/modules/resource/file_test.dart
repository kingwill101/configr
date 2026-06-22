import 'dart:io';
import 'package:test/test.dart';
import 'package:configr/src/modules/resource/file.dart';
import 'package:configr/src/models/action.dart';
import 'package:configr/src/models/file_model.dart';
import 'package:configr/src/exceptions.dart';

void main() {
  group('FileFileModule', () {
    late Directory tempDir;
    late FileFileModule fileModule;
    late Action action;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('configr_file_test_');
      action = Action(
        id: 'test_file_action',
        type: 'file',
        properties: {
          'operation': 'create',
          'content': 'Hello, World!',
          'create_directories': 'true',
          'backup_original': 'false',
        },
      );
      
      final resource = ResourceModel(
        id: 'test_resource',
        type: 'file',
        source: 'test_source',
        destination: '${tempDir.path}/test.txt',
        actions: [action],
      );
      
      fileModule = FileFileModule(resource, action);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('should initialize with default values', () {
      expect(fileModule.operation, equals('create'));
      expect(fileModule.content, equals(''));
      expect(fileModule.filePath, equals(''));
      expect(fileModule.source, equals('test_source'));
      expect(fileModule.destination, equals('${tempDir.path}/test.txt'));
      expect(fileModule.createDirectories, equals(true));
      expect(fileModule.backupOriginal, equals(false));
      expect(fileModule.backupSuffix, equals('.backup'));
      expect(fileModule.editMode, equals('replace'));
      expect(fileModule.operationSuccess, equals(false));
    });

    test('should update state with configuration', () {
      // Manually call updateState to simulate configuration parsing
      fileModule.updateState({
        'operation': 'create',
        'content': 'Test content',
        'filePath': '/test/path.txt',
        'source': 'test_source',
        'destination': '/test/destination.txt',
        'createDirectories': true,
        'backupOriginal': true,
        'backupSuffix': '.bak',
        'editMode': 'append',
      });

      expect(fileModule.operation, equals('create'));
      expect(fileModule.content, equals('Test content'));
      expect(fileModule.filePath, equals('/test/path.txt'));
      expect(fileModule.source, equals('test_source'));
      expect(fileModule.destination, equals('/test/destination.txt'));
      expect(fileModule.createDirectories, equals(true));
      expect(fileModule.backupOriginal, equals(true));
      expect(fileModule.backupSuffix, equals('.bak'));
      expect(fileModule.editMode, equals('append'));
    });

    test('should create file successfully', () async {
      final testFile = File('${tempDir.path}/create_test.txt');
      expect(testFile.existsSync(), isFalse);

      // Update resource destination for create operation
      final resource = ResourceModel(
        id: 'test_resource',
        type: 'file',
        source: 'test_source',
        destination: testFile.path,
        actions: [action],
      );
      fileModule = FileFileModule(resource, action);
      
      action.properties['content'] = 'Created by test';
      action.properties['create_directories'] = 'true';

      await fileModule.execute();

      expect(testFile.existsSync(), isTrue);
      expect(await testFile.readAsString(), equals('Created by test'));
      expect(fileModule.operationSuccess, isTrue);
    });

    test('should edit file successfully', () async {
      final testFile = File('${tempDir.path}/edit_test.txt');
      await testFile.writeAsString('Original content');

      // Update resource destination for edit operation
      final resource = ResourceModel(
        id: 'test_resource',
        type: 'file',
        source: 'test_source',
        destination: testFile.path,
        actions: [action],
      );
      fileModule = FileFileModule(resource, action);

      // Update action properties for edit operation
      action.properties['operation'] = 'edit';
      action.properties['content'] = '\nAppended content';
      action.properties['edit_mode'] = 'append';

      await fileModule.execute();

      expect(await testFile.readAsString(), equals('Original content\nAppended content'));
      expect(fileModule.operationSuccess, isTrue);
    });

    test('should remove file successfully', () async {
      final testFile = File('${tempDir.path}/remove_test.txt');
      await testFile.writeAsString('To be removed');
      expect(testFile.existsSync(), isTrue);

      // Update resource destination for remove operation
      final resource = ResourceModel(
        id: 'test_resource',
        type: 'file',
        source: 'test_source',
        destination: testFile.path,
        actions: [action],
      );
      fileModule = FileFileModule(resource, action);

      // Update action properties for remove operation
      action.properties['operation'] = 'remove';

      await fileModule.execute();

      expect(testFile.existsSync(), isFalse);
      expect(fileModule.operationSuccess, isTrue);
    });

    test('should validate unknown operation', () {
      action.properties['operation'] = 'unknown';
      
      expect(
        () => fileModule.execute(),
        throwsA(isA<ActionFailedException>()),
      );
    });

    test('should validate missing file path for create', () {
      final resource = ResourceModel(
        id: 'test_resource',
        type: 'file',
        source: 'test_source',
        destination: '', // Empty destination
        actions: [action],
      );
      fileModule = FileFileModule(resource, action);
      
      expect(
        () => fileModule.execute(),
        throwsA(isA<ActionFailedException>()),
      );
    });

    test('should validate missing file path for edit', () {
      final resource = ResourceModel(
        id: 'test_resource',
        type: 'file',
        source: 'test_source',
        destination: '', // Empty destination
        actions: [action],
      );
      fileModule = FileFileModule(resource, action);
      
      action.properties['operation'] = 'edit';
      
      expect(
        () => fileModule.execute(),
        throwsA(isA<ActionFailedException>()),
      );
    });

    test('should validate missing file path for remove', () {
      final resource = ResourceModel(
        id: 'test_resource',
        type: 'file',
        source: 'test_source',
        destination: '', // Empty destination
        actions: [action],
      );
      fileModule = FileFileModule(resource, action);
      
      action.properties['operation'] = 'remove';
      
      expect(
        () => fileModule.execute(),
        throwsA(isA<ActionFailedException>()),
      );
    });

    test('should validate file does not exist for edit', () {
      final resource = ResourceModel(
        id: 'test_resource',
        type: 'file',
        source: 'test_source',
        destination: '${tempDir.path}/nonexistent.txt',
        actions: [action],
      );
      fileModule = FileFileModule(resource, action);
      
      action.properties['operation'] = 'edit';
      
      expect(
        () => fileModule.execute(),
        throwsA(isA<ActionFailedException>()),
      );
    });

    test('should validate unknown edit mode', () async {
      final testFile = File('${tempDir.path}/edit_mode_test.txt');
      await testFile.writeAsString('Original content');

      final resource = ResourceModel(
        id: 'test_resource',
        type: 'file',
        source: 'test_source',
        destination: testFile.path,
        actions: [action],
      );
      fileModule = FileFileModule(resource, action);

      action.properties['operation'] = 'edit';
      action.properties['edit_mode'] = 'unknown';
      
      expect(
        () => fileModule.execute(),
        throwsA(isA<ActionFailedException>()),
      );
    });
  });
}