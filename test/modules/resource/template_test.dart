import 'package:test/test.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/models/file_model.dart';
import 'package:configr/models/action.dart';
import 'package:configr/models/template.dart';
import '../../helpers/test_helper.dart';

void main() {
  late TestHelper helper;

  setUp(() {
    helper = TestHelper();
  });

  test('should render template with variables', () async {
    // Arrange
    const templatePath = 'templates/test.template';
    const templateContent = 'Hello, {{ name }}!';
    const destPath = '/dest/result.txt';
    await helper.createDirectory('templates');
    await helper.createTestFile(templatePath, templateContent);

    final resourceModel = ResourceModel(
        source: templatePath,
        destination: destPath,
        template: Template(template: templatePath, vars: {'name': 'World'}),
        actions: [Action(type: 'copy')]);

    final module = await getModuleForAction(
        resourceModel, resourceModel.actions.first, helper.fileSystem);

    // Act
    await module();

    // Assert
    await helper.verifyFileContent(destPath, 'Hello, World!');
  });
}
