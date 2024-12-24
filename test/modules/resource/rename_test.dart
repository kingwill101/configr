import 'package:test/test.dart';
import 'package:configr/modules/resource/rename.dart';
import 'package:configr/models/file_model.dart';
import 'package:configr/models/action.dart';
import '../../helpers/test_helper.dart';

void main() {
  late TestHelper helper;

  setUp(() {
    helper = TestHelper();
  });

  test('should rename file successfully', () async {
    // Arrange
    const sourcePath = 'test/oldname.txt';
    const destPath = 'test/newname.txt';
    const content = 'test content';

    await helper.createTestFile(sourcePath, content);

    final resourceModel = ResourceModel(
        source: sourcePath,
        destination: destPath,
        actions: [Action(type: 'rename')]);

    final module = FileRenameModule(resourceModel, resourceModel.actions.first,
        fileSystem: helper.fileSystem);

    // Act
    await module();

    // Assert
    expect(await helper.fileExists(sourcePath), isFalse);
    expect(await helper.fileExists(destPath), isTrue);
    await helper.verifyFileContent(destPath, content);
  });

  test('should fail when destination exists and overwrite is false', () async {
    // Arrange
    const sourcePath = 'test/source.txt';
    const destPath = 'test/dest.txt';

    await helper.createTestFile(sourcePath, 'source content');
    await helper.createTestFile(destPath, 'destination content');

    final resourceModel =
        ResourceModel(source: sourcePath, destination: destPath, actions: [
      Action(type: 'rename', properties: {'overwrite': 'false'})
    ]);

    final module = FileRenameModule(resourceModel, resourceModel.actions.first,
        fileSystem: helper.fileSystem);

    // Act & Assert
    expect(() => module(), throwsException);
  });
}
