import 'package:configr/models/action.dart';
import 'package:configr/models/file_model.dart';
import 'package:configr/modules/resource/permissions.dart';
import 'package:configr/utils/file_utils.dart';
import 'package:file/local.dart';
import 'package:test/test.dart';

import '../../helpers/test_helper.dart';

void main() {
  late TestHelper helper;

  if (TestHelper.inCi()) {
    return;
  }

  setUp(() {
    final fileSystem = LocalFileSystem();
    helper = TestHelper(fileSystem.systemTempDirectory.path);
    helper.fileSystem = fileSystem;
  });

  group('FilePermissionModule', () {
    late String filePath;

    setUp(() {
      filePath = helper.resolvePath('file.txt');
    });

    tearDown(() async {
      await helper.deleteTestFile(filePath);
    });

    test('should change all permissions successfully', () async {
      await helper.createTestFile(filePath, 'test content');

      final resourceModel = ResourceModel(
        source: filePath,
        destination: '',
        actions: [
          Action(
            type: 'permissions',
            properties: {
              'mode': '644',
              'owner': 'testuser',
              'group': 'testgroup'
            },
          ),
        ],
      );

      final module = FilePermissionModule(
        resourceModel,
        resourceModel.actions.first,
        fileSystem: helper.fileSystem,
      );

      await module();

      // Verify all changes
      await helper.verifyFilePermissions(filePath, int.parse('644', radix: 8));
      await helper.verifyFileOwnership(filePath,
          owner: 'testuser', group: 'testgroup');
    });

    test('should change only mode when specified', () async {
      await helper.createTestFile(filePath, 'test content');

      final resourceModel = ResourceModel(
        source: filePath,
        destination: '',
        actions: [
          Action(
            type: 'permissions',
            properties: {
              'mode': '644',
            },
          ),
        ],
      );

      final module = FilePermissionModule(
        resourceModel,
        resourceModel.actions.first,
        fileSystem: helper.fileSystem,
      );

      await module();

      await helper.verifyFilePermissions(filePath, int.parse('644', radix: 8));
    });

    test('should change only ownership when specified', () async {
      await helper.createTestFile(filePath, 'test content');

      final resourceModel = ResourceModel(
        source: filePath,
        destination: '',
        actions: [
          Action(
            type: 'permissions',
            properties: {'owner': 'testuser', 'group': 'testgroup'},
          ),
        ],
      );

      final module = FilePermissionModule(
        resourceModel,
        resourceModel.actions.first,
        fileSystem: helper.fileSystem,
      );

      await module();

      await helper.verifyFileOwnership(filePath,
          owner: 'testuser', group: 'testgroup');
    });

    test('should throw when no properties specified', () async {
      await helper.createTestFile(filePath, 'test content');

      final resourceModel = ResourceModel(
        source: filePath,
        destination: '',
        actions: [
          Action(
            type: 'permissions',
            properties: {},
          ),
        ],
      );

      expect(
        () => FilePermissionModule(
          resourceModel,
          resourceModel.actions.first,
          fileSystem: helper.fileSystem,
        ),
        throwsArgumentError,
      );
    });

    test('should rollback changes on failure', () async {
      await helper.createTestFile(filePath, 'test content');

      // Get original permissions/ownership
      final originalMode = await FileUtils.getPermissions(filePath);
      final originalOwnership = await FileUtils.getOwnership(filePath);

      final resourceModel = ResourceModel(
        source: filePath,
        destination: '',
        actions: [
          Action(
            type: 'permissions',
            properties: {
              'mode': '000', // Invalid permissions that should fail
              'owner': 'testuser',
              'group': 'testgroup'
            },
          ),
        ],
      );

      final module = FilePermissionModule(
        resourceModel,
        resourceModel.actions.first,
        fileSystem: helper.fileSystem,
      );

      try {
        await module();
        fail('Should have thrown an exception');
      } catch (e) {
        // Verify rollback
        final currentMode = await FileUtils.getPermissions(filePath);
        final currentOwnership = await FileUtils.getOwnership(filePath);

        expect(currentMode, equals(originalMode));
        expect(currentOwnership, equals(originalOwnership));
      }
    });
  });
}
