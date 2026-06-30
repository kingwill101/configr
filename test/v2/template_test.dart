import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should initialize with default values', () async {
    const templatePath = '/template.txt';
    const outputPath = '/output.txt';
    await helper.createFile(templatePath, 'Hello {{name}}!');

    final blocks = await helper.processConfig('''
      template {
        source = "$templatePath"
        destination = "$outputPath"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first;
    expect(block.blockType, equals('template'));
  });

  test('should process simple template', () async {
    const templatePath = '/template.txt';
    const outputPath = '/output.txt';
    await helper.createFile(templatePath, 'Hello World!');

    await helper.runConfig('''
      template {
        source = "$templatePath"
        destination = "$outputPath"
      }
    ''');

    expect(await helper.fileExists(outputPath), isTrue);
    final content = await helper.readFile(outputPath);
    expect(content, equals('Hello World!'));
  });

  test('should process template with configuration options', () async {
    const templatePath = '/template.txt';
    const outputPath = '/output_config.txt';
    await helper.createFile(templatePath, 'Test template');

    final blocks = await helper.processConfig('''
      template {
        source = "$templatePath"
        destination = "$outputPath"
        validate = false
        backup_original = true
        backup_suffix = ".bak"
      }
    ''');

    final block = blocks.first;
    expect((block as dynamic).validateTemplate, isFalse);
    expect((block as dynamic).backupOriginal, isTrue);
    expect((block as dynamic).backupSuffix, equals('.bak'));
  });
}
