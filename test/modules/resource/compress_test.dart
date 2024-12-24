import 'package:test/test.dart';
import 'package:configr/modules/resource/compress.dart';
import 'package:configr/models/file_model.dart';
import 'package:configr/models/action.dart';
import '../../helpers/test_helper.dart';

void main() {
  late TestHelper helper;

  setUp(() {
    helper = TestHelper();
  });

  group('FileCompressModule', () {
    test('should compress directory successfully', () async {
      // Arrange
      const sourcePath = 'source';
      const destPath = 'dest/archive.zip';
      await helper.createDirectory(sourcePath);
      assert(await helper.directoryExists(sourcePath));
      await helper.createTestFile('$sourcePath/file1.txt', 'content1');
      await helper.createTestFile('$sourcePath/file2.txt', 'content2');

      final resourceModel = ResourceModel(
          source: sourcePath,
          destination: destPath,
          type: ResourceType.directory,
          actions: [
            Action(
                type: 'compress',
                properties: {'format': 'zip', 'recursive': 'true'})
          ]);

      final module = FileCompressModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      final archive = helper.fileSystem.file(module.destination);
      expect(await archive.exists(), isTrue);
      expect(await archive.length(), greaterThan(0));
    });

    test('should handle decompression correctly', () async {
      // Test implementation for decompression
    });
  });
}
