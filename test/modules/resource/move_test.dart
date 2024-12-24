import 'package:test/test.dart';
import 'package:configr/modules/resource/move.dart';
import 'package:configr/models/file_model.dart';
import 'package:configr/models/action.dart';
import '../../helpers/test_helper.dart';

void main() {
  late TestHelper helper;

  setUp(() {
    helper = TestHelper();
  });

  test('should move file successfully', () async {
    // Arrange
    const sourcePath = 'source/test.txt';
    const destPath = 'dest/test.txt';
    const content = 'test content';

    await helper.createTestFile(sourcePath, content);

    final resourceModel = ResourceModel(
        source: sourcePath,
        destination: destPath,
        actions: [Action(type: 'move')]);

    final module = FileMoveModule(resourceModel, resourceModel.actions.first,
        fileSystem: helper.fileSystem);

    // Act
    await module();

    // Assert
    expect(await helper.fileExists(sourcePath), isFalse);
    expect(await helper.fileExists(destPath), isTrue);
    await helper.verifyFileContent(destPath, content);
  });

  test('should handle rollback correctly', () async {
    // Arrange
    const sourcePath = 'source/test.txt';
    const destPath = 'dest/test.txt';
    const content = 'test content';

    await helper.createTestFile(sourcePath, content);

    final resourceModel = ResourceModel(
        source: sourcePath,
        destination: destPath,
        actions: [Action(type: 'move')]);

    final module = FileMoveModule(resourceModel, resourceModel.actions.first,
        fileSystem: helper.fileSystem);

    // Act
    await module();
    await module.rollback();

    // Assert
    expect(await helper.fileExists(sourcePath), isTrue);
    expect(await helper.fileExists(destPath), isFalse);
    await helper.verifyFileContent(sourcePath, content);
  });
}
