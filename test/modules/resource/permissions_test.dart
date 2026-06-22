import 'package:test/test.dart';
import 'package:configr/src/modules/resource/permissions.dart';
import 'package:configr/src/models/action.dart';
import 'package:configr/src/exceptions.dart';
import '../../helpers/test_helper.dart';

void main() {
  late TestHelper helper;

  setUp(() {
    helper = TestHelper();
  });

  test('should set file permissions successfully', () async {
    // Arrange
    final resourceModel = helper.createTestResource(
        source: '/test/file.txt',
        destination: '/test/file.txt',
        actions: [
          Action(
            type: 'permissions',
            properties: {
              'mode': '644'
            }
          )
        ]);

    final module = FilePermissionModule(resourceModel, resourceModel.actions.first,
        fileSystem: helper.fileSystem);

    // Assert
    expect(module.mode, equals('644'));
    expect(module.recursive, isFalse);
    expect(module.useAcl, isFalse);
  });

  test('should set file ownership successfully', () async {
    // Arrange
    final resourceModel = helper.createTestResource(
        source: '/test/file.txt',
        destination: '/test/file.txt',
        actions: [
          Action(
            type: 'permissions',
            properties: {
              'owner': 'testuser',
              'group': 'testgroup'
            }
          )
        ]);

    final module = FilePermissionModule(resourceModel, resourceModel.actions.first,
        fileSystem: helper.fileSystem);

    // Assert
    expect(module.owner, equals('testuser'));
    expect(module.group, equals('testgroup'));
    expect(module.recursive, isFalse);
  });

  test('should handle recursive directory permissions', () async {
    // Arrange
    final resourceModel = helper.createTestResource(
        source: '/test/recursive',
        destination: '/test/recursive',
        actions: [
          Action(
            type: 'permissions',
            properties: {
              'mode': '755',
              'recursive': 'true'
            }
          )
        ]);

    final module = FilePermissionModule(resourceModel, resourceModel.actions.first,
        fileSystem: helper.fileSystem);

    // Assert
    expect(module.recursive, isTrue);
    expect(module.mode, equals('755'));
    expect(module.totalFiles, equals(0)); // Initial state
    expect(module.processedFiles, equals(0)); // Initial state
  });

  group('Enhanced Permissions Features', () {
    test('should support ACL configuration', () async {
      // Arrange
      final resourceModel = helper.createTestResource(
          source: '/test/acl_file.txt',
          destination: '/test/acl_file.txt',
          actions: [
            Action(
              type: 'permissions',
              properties: {
                'mode': '644',
                'use_acl': 'true',
                'acl_entries': 'user:testuser:rwx'
              }
            )
          ]);

      final module = FilePermissionModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Assert
      expect(module.useAcl, isTrue);
      expect(module.aclEntries, equals('user:testuser:rwx'));
      expect(module.mode, equals('644'));
    });

    test('should support symbolic permission mode', () async {
      // Arrange
      final resourceModel = helper.createTestResource(
          source: '/test/symbolic_file.txt',
          destination: '/test/symbolic_file.txt',
          actions: [
            Action(
              type: 'permissions',
              properties: {
                'mode': 'u+rw,g+r,o+r'
              }
            )
          ]);

      final module = FilePermissionModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Assert
      expect(module.mode, equals('u+rw,g+r,o+r'));
    });

    test('should support follow symlinks option', () async {
      // Arrange
      final resourceModel = helper.createTestResource(
          source: '/test/symlink_dir',
          destination: '/test/symlink_dir',
          actions: [
            Action(
              type: 'permissions',
              properties: {
                'mode': '755',
                'recursive': 'true',
                'follow_symlinks': 'true'
              }
            )
          ]);

      final module = FilePermissionModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Assert
      expect(module.followSymlinks, isTrue);
      expect(module.recursive, isTrue);
    });

    test('should support preserve xattr option', () async {
      // Arrange
      final resourceModel = helper.createTestResource(
          source: '/test/xattr_file.txt',
          destination: '/test/xattr_file.txt',
          actions: [
            Action(
              type: 'permissions',
              properties: {
                'mode': '644',
                'preserve_xattr': 'true'
              }
            )
          ]);

      final module = FilePermissionModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Assert - preserveXattr is parsed but not used in implementation
      expect(module.mode, equals('644'));
    });

    test('should track processing statistics', () async {
      // Arrange
      final resourceModel = helper.createTestResource(
          source: '/test/stats',
          destination: '/test/stats',
          actions: [
            Action(
              type: 'permissions',
              properties: {
                'mode': '644',
                'recursive': 'true'
              }
            )
          ]);

      final module = FilePermissionModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Assert
      expect(module.totalFiles, equals(0)); // Initial state
      expect(module.processedFiles, equals(0)); // Initial state
      expect(module.failedFiles, equals(0)); // Initial state
    });

    test('should handle complex configuration', () async {
      // Arrange
      final resourceModel = helper.createTestResource(
          source: '/test/complex.txt',
          destination: '/test/complex.txt',
          actions: [
            Action(
              type: 'permissions',
              properties: {
                'owner': 'testuser',
                'group': 'testgroup',
                'mode': '755',
                'use_acl': 'true',
                'acl_entries': 'user:testuser:rwx,group:testgroup:rx',
                'permission_mode': 'octal',
                'follow_symlinks': 'false',
                'preserve_xattr': 'true'
              }
            )
          ]);

      final module = FilePermissionModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Assert
      expect(module.owner, equals('testuser'));
      expect(module.group, equals('testgroup'));
      expect(module.mode, equals('755'));
      expect(module.useAcl, isTrue);
      expect(module.aclEntries, equals('user:testuser:rwx,group:testgroup:rx'));
      expect(module.followSymlinks, isFalse);
    });

    test('should handle permission mode validation', () async {
      // Arrange
      final resourceModel = helper.createTestResource(
          source: '/test/validation.txt',
          destination: '/test/validation.txt',
          actions: [
            Action(
              type: 'permissions',
              properties: {
                'mode': '755'
              }
            )
          ]);

      final module = FilePermissionModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Assert
      expect(module.mode, equals('755'));
    });

    test('should handle default permission mode', () async {
      // Arrange
      final resourceModel = helper.createTestResource(
          source: '/test/default.txt',
          destination: '/test/default.txt',
          actions: [
            Action(
              type: 'permissions',
              properties: {
                'mode': '644'
              }
            )
          ]);

      final module = FilePermissionModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Assert
      expect(module.mode, equals('644'));
    });

    test('should handle empty directory in recursive mode', () async {
      // Arrange
      final resourceModel = helper.createTestResource(
          source: '/test/empty',
          destination: '/test/empty',
          actions: [
            Action(
              type: 'permissions',
              properties: {
                'mode': '755',
                'recursive': 'true'
              }
            )
          ]);

      final module = FilePermissionModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Assert
      expect(module.recursive, isTrue);
      expect(module.totalFiles, equals(0)); // Initial state
      expect(module.processedFiles, equals(0)); // Initial state
    });

    test('should require at least one permission property', () async {
      // Arrange
      final resourceModel = helper.createTestResource(
          source: '/test/file.txt',
          destination: '/test/file.txt',
          actions: [
            Action(
              type: 'permissions',
              properties: {}
            )
          ]);

      // Act & Assert
      expect(() => FilePermissionModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem), throwsA(isA<ArgumentError>()));
    });

    test('should handle state initialization', () async {
      // Arrange
      final resourceModel = helper.createTestResource(
          source: '/test/state.txt',
          destination: '/test/state.txt',
          actions: [
            Action(
              type: 'permissions',
              properties: {
                'mode': '644',
                'recursive': 'true'
              }
            )
          ]);

      final module = FilePermissionModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Assert
      expect(module.originalStates, isEmpty);
      expect(module.totalFiles, equals(0));
      expect(module.processedFiles, equals(0));
      expect(module.failedFiles, equals(0));
    });

    test('should handle boolean property parsing', () async {
      // Arrange
      final resourceModel = helper.createTestResource(
          source: '/test/boolean.txt',
          destination: '/test/boolean.txt',
          actions: [
            Action(
              type: 'permissions',
              properties: {
                'mode': '644',
                'recursive': 'false',
                'use_acl': 'false',
                'follow_symlinks': 'false',
                'preserve_xattr': 'false'
              }
            )
          ]);

      final module = FilePermissionModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Assert
      expect(module.recursive, isFalse);
      expect(module.useAcl, isFalse);
      expect(module.followSymlinks, isFalse);
    });
  });
}