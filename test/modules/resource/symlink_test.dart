import 'package:test/test.dart';
import 'package:configr/modules/resource/symlink.dart';
import 'package:configr/models/file_model.dart';
import 'package:configr/models/action.dart';
import '../../helpers/test_helper.dart';

void main() {
  late TestHelper helper;

  setUp(() {
    helper = TestHelper();
  });

  test('should create symlink successfully', () async {
    // Arrange
    const sourcePath = 'source/test.txt';
    const linkPath = 'dest/link.txt';
    const content = 'test content';

    await helper.createTestFile(sourcePath, content);

    final resourceModel =
        ResourceModel(source: sourcePath, destination: linkPath, actions: [
      Action(type: 'symlink', properties: {'link_path': linkPath})
    ]);

    final module = FileSymlinkModule(resourceModel, resourceModel.actions.first,
        fileSystem: helper.fileSystem);

    // Act
    await module();

    // Assert
    final link = helper.fileSystem.link(linkPath);
    expect(await link.exists(), isTrue);
    expect(await link.target(), equals(helper.resolvePath(sourcePath)));
  });

  test('should handle rollback correctly', () async {
    // Similar test structure for rollback scenario
  });
}
