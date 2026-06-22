import 'package:test/test.dart';
import 'package:configr/src/modules/resource/resource_module.dart';
import 'package:configr/src/modules/resource/backup.dart';
import 'package:configr/src/modules/resource/compress.dart';
import 'package:configr/src/modules/resource/copy.dart';
import 'package:configr/src/modules/resource/decompress.dart';
import 'package:configr/src/modules/resource/delete.dart';
import 'package:configr/src/modules/resource/download.dart';
import 'package:configr/src/modules/resource/echo.dart';
import 'package:configr/src/modules/resource/execute.dart';
import 'package:configr/src/modules/resource/permissions.dart';
import 'package:configr/src/modules/resource/rename.dart';
import 'package:configr/src/modules/resource/symlink.dart';
import 'package:configr/src/modules/resource/touch.dart';
import 'package:configr/src/modules/resource/validate.dart';
import 'package:configr/src/models/action.dart';

import '../../helpers/test_helper.dart';

void main() {
  late TestHelper helper;

  setUp(() {
    helper = TestHelper();
  });

  test('getModuleForAction returns correct module types for all supported actions', () {
    final resourceModel = helper.createTestResource(
      source: 'test',
      destination: 'test',
      actions: [
        Action(type: 'backup', properties: {'backup_path': 'test.bak'}),
        Action(type: 'compress', properties: {}),
        Action(type: 'copy', properties: {}),
        Action(type: 'decompress', properties: {}),
        Action(type: 'delete', properties: {}),
        Action(type: 'download', properties: {'source': 'http://example.com/file'}),
        Action(type: 'echo', properties: {'message': 'test'}),
        Action(type: 'execute', properties: {'command': 'test'}),
        Action(type: 'permissions', properties: {'mode': '644'}),
        Action(type: 'rename', properties: {'new_name': 'renamed'}),
        Action(type: 'symlink', properties: {}),
        Action(type: 'touch', properties: {}),
        Action(type: 'validate', properties: {}),
      ],
    );

    final modules = resourceModel.actions.map((action) =>
        getModuleForAction(resourceModel, action, helper.fileSystem));

    expect(modules.elementAt(0), isA<FileBackupModule>());
    expect(modules.elementAt(1), isA<FileCompressModule>());
    expect(modules.elementAt(2), isA<FileCopyModule>());
    expect(modules.elementAt(3), isA<FileDecompressModule>());
    expect(modules.elementAt(4), isA<FileDeleteModule>());
    expect(modules.elementAt(5), isA<FileDownloadModule>());
    expect(modules.elementAt(6), isA<FileEchoModule>());
    expect(modules.elementAt(7), isA<FileExecuteModule>());
    expect(modules.elementAt(8), isA<FilePermissionModule>());
    expect(modules.elementAt(9), isA<FileRenameModule>());
    expect(modules.elementAt(10), isA<FileSymlinkModule>());
    expect(modules.elementAt(11), isA<FileTouchModule>());
    expect(modules.elementAt(12), isA<FileValidateModule>());
  });

  test('getModuleForAction throws exception for unknown action type', () {
    final resourceModel = helper.createTestResource(
      source: 'test',
      destination: 'test',
      actions: [Action(type: 'unknown', properties: {})],
    );

    expect(
          () => getModuleForAction(resourceModel, resourceModel.actions[0], helper.fileSystem),
      throwsException,
    );
  });
}
