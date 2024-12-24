import 'package:test/test.dart';
import 'package:configr/modules/resource/delete.dart';
import 'package:configr/models/file_model.dart';
import 'package:configr/models/action.dart';
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

    final resourceModel = ResourceModel(
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
        ResourceModel(source: filePath, destination: '', actions: [
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
}
