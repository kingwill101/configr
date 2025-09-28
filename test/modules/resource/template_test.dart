import 'package:configr/models/action.dart';
import 'package:configr/models/file_model.dart';
import 'package:configr/modules/resource/template.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';

void main() {
  group('FileTemplateModule', () {
    late FileSystem fileSystem;
    late Directory tempDir;
    late File templateFile;
    late File outputFile;

    setUp(() {
      fileSystem = MemoryFileSystem();
      tempDir = fileSystem.systemTempDirectory.createTempSync();
      templateFile = tempDir.childFile('template.txt');
      outputFile = tempDir.childFile('output.txt');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('should process simple template with variable substitution', () async {
      // Arrange
      const templateContent = 'Hello {{ name }}, welcome to {{ app }}!';
      templateFile.writeAsStringSync(templateContent);

      final file = ResourceModel(
        id: 'test-file',
        source: templateFile.path,
        destination: outputFile.path,
        type: 'template',
        actions: [],
      );

      final action = Action(
        id: 'test-action',
        type: 'template',
        properties: {
          'template_vars': {
            'name': 'John',
            'app': 'Configr',
          },
        },
      );

      final module = FileTemplateModule(file, action, fileSystem: fileSystem);

      // Act
      await module.execute();

      // Assert
      expect(outputFile.existsSync(), isTrue);
      final content = outputFile.readAsStringSync();
      expect(content, equals('Hello John, welcome to Configr!'));
    });

    test('should process template with conditional logic', () async {
      // Arrange
      const templateContent = '''
{% if user.isAdmin %}
Welcome, Administrator {{ user.name }}!
{% else %}
Welcome, {{ user.name }}!
{% endif %}
''';
      templateFile.writeAsStringSync(templateContent);

      final file = ResourceModel(
        id: 'test-file',
        source: templateFile.path,
        destination: outputFile.path,
        type: 'template',
        actions: [],
      );

      final action = Action(
        id: 'test-action',
        type: 'template',
        properties: {
          'template_vars': {
            'user': {
              'name': 'Alice',
              'isAdmin': true,
            },
          },
        },
      );

      final module = FileTemplateModule(file, action, fileSystem: fileSystem);

      // Act
      await module.execute();

      // Assert
      expect(outputFile.existsSync(), isTrue);
      final content = outputFile.readAsStringSync();
      expect(content.trim(), equals('Welcome, Administrator Alice!'));
    });

    test('should process template with loop constructs', () async {
      // Arrange
      const templateContent = '''
{% for item in items %}
- {{ item.name }}: {{ item.value }}
{% endfor %}
''';
      templateFile.writeAsStringSync(templateContent);

      final file = ResourceModel(
        id: 'test-file',
        source: templateFile.path,
        destination: outputFile.path,
        type: 'template',
        actions: [],
      );

      final action = Action(
        id: 'test-action',
        type: 'template',
        properties: {
          'template_vars': {
            'items': [
              {'name': 'Item 1', 'value': 'Value 1'},
              {'name': 'Item 2', 'value': 'Value 2'},
            ],
          },
        },
      );

      final module = FileTemplateModule(file, action, fileSystem: fileSystem);

      // Act
      await module.execute();

      // Assert
      expect(outputFile.existsSync(), isTrue);
      final content = outputFile.readAsStringSync();
      expect(content.trim(), equals('- Item 1: Value 1\n\n- Item 2: Value 2'));
    });

    test('should create backup of original file when backup_original is true', () async {
      // Arrange
      const templateContent = 'Hello {{ name }}!';
      templateFile.writeAsStringSync(templateContent);
      
      // Create original output file
      const originalContent = 'Original content';
      outputFile.writeAsStringSync(originalContent);

      final file = ResourceModel(
        id: 'test-file',
        source: templateFile.path,
        destination: outputFile.path,
        type: 'template',
        actions: [],
      );

      final action = Action(
        id: 'test-action',
        type: 'template',
        properties: {
          'template_vars': {'name': 'World'},
          'backup_original': true,
          'backup_suffix': '.bak',
        },
      );

      final module = FileTemplateModule(file, action, fileSystem: fileSystem);

      // Act
      await module.execute();

      // Assert
      expect(outputFile.existsSync(), isTrue);
      final backupFile = tempDir.childFile('output.txt.bak');
      expect(backupFile.existsSync(), isTrue);
      expect(backupFile.readAsStringSync(), equals(originalContent));
    });

    test('should rollback template processing correctly', () async {
      // Arrange
      const templateContent = 'Hello {{ name }}!';
      templateFile.writeAsStringSync(templateContent);
      
      // Create original output file
      const originalContent = 'Original content';
      outputFile.writeAsStringSync(originalContent);

      final file = ResourceModel(
        id: 'test-file',
        source: templateFile.path,
        destination: outputFile.path,
        type: 'template',
        actions: [],
      );

      final action = Action(
        id: 'test-action',
        type: 'template',
        properties: {
          'template_vars': {'name': 'World'},
        },
      );

      final module = FileTemplateModule(file, action, fileSystem: fileSystem);

      // Act
      await module.execute();
      await module.rollback();

      // Assert
      expect(outputFile.existsSync(), isTrue);
      expect(outputFile.readAsStringSync(), equals(originalContent));
    });

    test('should remove generated file on rollback if it did not exist originally', () async {
      // Arrange
      const templateContent = 'Hello {{ name }}!';
      templateFile.writeAsStringSync(templateContent);

      final file = ResourceModel(
        id: 'test-file',
        source: templateFile.path,
        destination: outputFile.path,
        type: 'template',
        actions: [],
      );

      final action = Action(
        id: 'test-action',
        type: 'template',
        properties: {
          'template_vars': {'name': 'World'},
        },
      );

      final module = FileTemplateModule(file, action, fileSystem: fileSystem);

      // Act
      await module.execute();
      expect(outputFile.existsSync(), isTrue);
      
      await module.rollback();

      // Assert
      expect(outputFile.existsSync(), isFalse);
    });

    test('should throw exception when template file does not exist', () async {
      // Arrange
      final file = ResourceModel(
        id: 'test-file',
        source: '/nonexistent/template.txt',
        destination: outputFile.path,
        type: 'template',
        actions: [],
      );

      final action = Action(
        id: 'test-action',
        type: 'template',
        properties: {
          'template_vars': {'name': 'World'},
        },
      );

      final module = FileTemplateModule(file, action, fileSystem: fileSystem);

      // Act & Assert
      expect(
        () => module.execute(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Template file does not exist'),
        )),
      );
    });

    test('should throw exception when template validation fails', () async {
      // Arrange
      const invalidTemplate = 'Hello {% if %}'; // Invalid if statement
      templateFile.writeAsStringSync(invalidTemplate);

      final file = ResourceModel(
        id: 'test-file',
        source: templateFile.path,
        destination: outputFile.path,
        type: 'template',
        actions: [],
      );

      final action = Action(
        id: 'test-action',
        type: 'template',
        properties: {
          'template_vars': {'name': 'World'},
          'validate_template': true,
        },
      );

      final module = FileTemplateModule(file, action, fileSystem: fileSystem);

      // Act & Assert
      expect(
        () => module.execute(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Template rendering failed'),
        )),
      );
    });

    test('should skip template validation when validate_template is false', () async {
      // Arrange
      const templateContent = 'Hello {{ name }}!';
      templateFile.writeAsStringSync(templateContent);

      final file = ResourceModel(
        id: 'test-file',
        source: templateFile.path,
        destination: outputFile.path,
        type: 'template',
        actions: [],
      );

      final action = Action(
        id: 'test-action',
        type: 'template',
        properties: {
          'template_vars': {'name': 'World'},
          'validate_template': false,
        },
      );

      final module = FileTemplateModule(file, action, fileSystem: fileSystem);

      // Act
      await module.execute();

      // Assert
      expect(outputFile.existsSync(), isTrue);
      final content = outputFile.readAsStringSync();
      expect(content, equals('Hello World!'));
    });

    test('should throw exception for unsupported template engine', () async {
      // Arrange
      const templateContent = 'Hello {{ name }}!';
      templateFile.writeAsStringSync(templateContent);

      final file = ResourceModel(
        id: 'test-file',
        source: templateFile.path,
        destination: outputFile.path,
        type: 'template',
        actions: [],
      );

      final action = Action(
        id: 'test-action',
        type: 'template',
        properties: {
          'template_vars': {'name': 'World'},
          'template_engine': 'unsupported',
        },
      );

      final module = FileTemplateModule(file, action, fileSystem: fileSystem);

      // Act & Assert
      expect(
        () => module.execute(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Unsupported template engine'),
        )),
      );
    });

    test('should create destination directory if it does not exist', () async {
      // Arrange
      const templateContent = 'Hello {{ name }}!';
      templateFile.writeAsStringSync(templateContent);
      
      final nestedOutputFile = tempDir.childDirectory('nested').childFile('output.txt');

      final file = ResourceModel(
        id: 'test-file',
        source: templateFile.path,
        destination: nestedOutputFile.path,
        type: 'template',
        actions: [],
      );

      final action = Action(
        id: 'test-action',
        type: 'template',
        properties: {
          'template_vars': {'name': 'World'},
        },
      );

      final module = FileTemplateModule(file, action, fileSystem: fileSystem);

      // Act
      await module.execute();

      // Assert
      expect(nestedOutputFile.existsSync(), isTrue);
      expect(nestedOutputFile.parent.existsSync(), isTrue);
      final content = nestedOutputFile.readAsStringSync();
      expect(content, equals('Hello World!'));
    });

    test('should track progress correctly', () async {
      // Arrange
      const templateContent = 'Hello {{ name }}!';
      templateFile.writeAsStringSync(templateContent);

      final file = ResourceModel(
        id: 'test-file',
        source: templateFile.path,
        destination: outputFile.path,
        type: 'template',
        actions: [],
      );

      final action = Action(
        id: 'test-action',
        type: 'template',
        properties: {
          'template_vars': {'name': 'World'},
          'show_progress': true,
        },
      );

      final module = FileTemplateModule(file, action, fileSystem: fileSystem);

      // Act
      await module.execute();

      // Assert
      expect(module.processedTemplates, equals(1));
      expect(module.showProgress, isTrue);
    });
  });
}