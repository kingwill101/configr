import 'package:test/test.dart';
import 'package:configr/modules/resource/validate.dart';
import 'package:configr/models/file_model.dart';
import 'package:configr/models/action.dart';
import '../../helpers/test_helper.dart';

void main() {
  late TestHelper helper;

  setUp(() {
    helper = TestHelper();
  });

  test('should validate JSON format successfully', () async {
    // Arrange
    const filePath = '/test/valid.json';
    const jsonContent = '{"name": "test", "value": 123}';

    await helper.createTestFile(filePath, jsonContent);

    final resourceModel =
        ResourceModel(source: filePath, destination: '', actions: [
      Action(type: 'validate', properties: {'format': 'json'})
    ]);

    final module = FileValidateModule(
        resourceModel, resourceModel.actions.first,
        fileSystem: helper.fileSystem);

    // Act & Assert
    expect(() async => await module(), returnsNormally);
  });

  test('should fail on invalid JSON format', () async {
    // Arrange
    const filePath = '/test/invalid.json';
    const invalidJson = '{invalid json}';

    await helper.createTestFile(filePath, invalidJson);

    final resourceModel =
        ResourceModel(source: filePath, destination: '', actions: [
      Action(type: 'validate', properties: {'format': 'json'})
    ]);

    final module = FileValidateModule(
        resourceModel, resourceModel.actions.first,
        fileSystem: helper.fileSystem);

    // Act & Assert
    expect(() async => await module(), throwsException);
  });
}
