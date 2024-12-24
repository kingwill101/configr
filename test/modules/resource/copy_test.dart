import 'package:test/test.dart';
import 'package:configr/modules/resource/copy.dart';
import 'package:configr/models/file_model.dart';
import 'package:configr/models/action.dart';
import 'package:configr/utils/file_utils.dart';
import '../../helpers/test_helper.dart';

void main() {
  late TestHelper helper;

  setUp(() {
    helper = TestHelper();
  });

  test('should copy file successfully', () async {
    // Arrange
    const sourceDir = '/source/dir';
    const destDir = '/dest/dir';

    const destinationFile = "$destDir/file1.txt";
    const sourceFile = "$sourceDir/file1.txt";
    const content = 'content1';

    await FileUtils.createDirectory(sourceDir, fileSystem: helper.fileSystem);
    await FileUtils.writeFile(sourceFile, content,
        fileSystem: helper.fileSystem);

    final resourceModel = ResourceModel(
        source: sourceFile,
        destination: destinationFile,
        actions: [Action(type: 'copy')]);

    final module = FileCopyModule(resourceModel, resourceModel.actions.first,
        fileSystem: helper.fileSystem);

    // Act
    await module();

    // Assert
    expect(
        await FileUtils.fileExists(destinationFile,
            fileSystem: helper.fileSystem),
        isTrue);
    expect(
        await FileUtils.readFile(destinationFile,
            fileSystem: helper.fileSystem),
        equals(content));
  });

  test('should handle directory copy', () async {
    // Arrange
    const sourceDir = '/source/dir';
    const destDir = '/dest/dir';

    await FileUtils.createDirectory(sourceDir, fileSystem: helper.fileSystem);
    await FileUtils.writeFile('$sourceDir/file1.txt', 'content1',
        fileSystem: helper.fileSystem);
    await FileUtils.writeFile('$sourceDir/file2.txt', 'content2',
        fileSystem: helper.fileSystem);

    final resourceModel = ResourceModel(
        source: sourceDir,
        destination: destDir,
        type: ResourceType.directory,
        actions: [
          Action(type: 'copy', properties: {'recursive': 'true'})
        ]);

    final module = FileCopyModule(resourceModel, resourceModel.actions.first,
        fileSystem: helper.fileSystem);

    // Act
    await module();

    // Assert
    expect(
        await FileUtils.directoryExists(destDir, fileSystem: helper.fileSystem),
        isTrue);
    expect(
        await FileUtils.readFile('$destDir/file1.txt',
            fileSystem: helper.fileSystem),
        equals('content1'));
    expect(
        await FileUtils.readFile('$destDir/file2.txt',
            fileSystem: helper.fileSystem),
        equals('content2'));
  });

  test('should handle rollback correctly', () async {
    const sourceDir = '/source/dir';
    const destDir = '/dest/dir';

    const destinationFile = "$destDir/file1.txt";
    const sourceFile = "$sourceDir/file1.txt";

    await FileUtils.createDirectory(sourceDir, fileSystem: helper.fileSystem);
    await FileUtils.writeFile(sourceFile, 'content1',
        fileSystem: helper.fileSystem);

    final resourceModel = ResourceModel(
        source: sourceFile,
        destination: destinationFile,
        actions: [Action(type: 'copy')]);

    final module = FileCopyModule(resourceModel, resourceModel.actions.first,
        fileSystem: helper.fileSystem);

    // Act
    await module();
    await module.rollback();

    // Assert
    expect(
        await FileUtils.fileExists(destinationFile,
            fileSystem: helper.fileSystem),
        isFalse);
  });

  test('should fail when source does not exist', () async {
    // Arrange
    const sourcePath = '/nonexistent/file.txt';
    const destPath = '/dest/file.txt';

    final resourceModel = ResourceModel(
        source: sourcePath,
        destination: destPath,
        actions: [Action(type: 'copy')]);

    final module = FileCopyModule(resourceModel, resourceModel.actions.first,
        fileSystem: helper.fileSystem);

    // Act & Assert
    expect(() async => await module(), throwsException);
  });
}
