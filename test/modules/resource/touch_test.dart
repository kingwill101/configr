import 'package:test/test.dart';
import 'package:configr/modules/resource/touch.dart';
import 'package:configr/models/file_model.dart';
import 'package:configr/models/action.dart';
import '../../helpers/test_helper.dart';

void main() {
  late TestHelper helper;

  setUp(() {
    helper = TestHelper();
  });

  test('should create new file when it does not exist', () async {
    // Arrange
    const filePath = 'test/newfile.txt';

    final resourceModel =
        ResourceModel(source: '', destination: filePath, actions: [
      Action(type: 'touch', properties: {'create_if_missing': 'true'})
    ]);

    final module = FileTouchModule(resourceModel, resourceModel.actions.first,
        fileSystem: helper.fileSystem);

    // Act
    await module();

    // Assert
    expect(await helper.fileExists(filePath), isTrue);
  });

  test('should update modification time of existing file', () async {
    // Arrange
    const filePath = 'test/existing.txt';
    await helper.createTestFile(filePath, 'test content');

    final resourceModel = ResourceModel(
        source: '', destination: filePath, actions: [Action(type: 'touch')]);

    final module = FileTouchModule(resourceModel, resourceModel.actions.first,
        fileSystem: helper.fileSystem);

    final beforeTime = helper.fileSystem.file(filePath).lastModifiedSync();

    // Wait a moment to ensure modification time will be different
    await Future.delayed(Duration(milliseconds: 100));

    // Act
    await module();

    // Assert
    final afterTime = helper.fileSystem.file(filePath).lastModifiedSync();
    expect(afterTime.isAfter(beforeTime), isTrue);
  });

  test('should fail when file does not exist and create_if_missing is false',
      () async {
    // Arrange
    const filePath = 'test/nonexistent.txt';

    final resourceModel =
        ResourceModel(source: '', destination: filePath, actions: [
      Action(type: 'touch', properties: {'create_if_missing': 'false'})
    ]);

    final module = FileTouchModule(resourceModel, resourceModel.actions.first,
        fileSystem: helper.fileSystem);

    // Act & Assert
    expect(() => module(), throwsException);
  });
}
