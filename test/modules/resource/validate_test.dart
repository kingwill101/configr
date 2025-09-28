import 'package:test/test.dart';
import 'package:configr/modules/resource/validate.dart';
import 'package:configr/models/action.dart';
import '../../helpers/test_helper.dart';

void main() {
  late TestHelper helper;

  setUp(() {
    helper = TestHelper();
  });

  group('JSON Format Validation', () {
    test('should validate JSON format successfully', () async {
      // Arrange
      const filePath = '/test/valid.json';
      const jsonContent = '{"name": "test", "value": 123}';

      await helper.createTestFile(filePath, jsonContent);

      final resourceModel =
          helper.createTestResource(source: filePath, destination: '', actions: [
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
          helper.createTestResource(source: filePath, destination: '', actions: [
        Action(type: 'validate', properties: {'format': 'json'})
      ]);

      final module = FileValidateModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act & Assert
      expect(() async => await module(), throwsException);
    });
  });

  group('YAML Format Validation', () {
    test('should validate YAML format successfully', () async {
      // Arrange
      const filePath = '/test/valid.yaml';
      const yamlContent = '''
name: test
value: 123
nested:
  key: value
''';

      await helper.createTestFile(filePath, yamlContent);

      final resourceModel =
          helper.createTestResource(source: filePath, destination: '', actions: [
        Action(type: 'validate', properties: {'format': 'yaml'})
      ]);

      final module = FileValidateModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act & Assert
      expect(() async => await module(), returnsNormally);
    });

    test('should fail on empty YAML file', () async {
      // Arrange
      const filePath = '/test/empty.yaml';
      const emptyYaml = '';

      await helper.createTestFile(filePath, emptyYaml);

      final resourceModel =
          helper.createTestResource(source: filePath, destination: '', actions: [
        Action(type: 'validate', properties: {'format': 'yaml'})
      ]);

      final module = FileValidateModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act & Assert
      expect(() async => await module(), throwsException);
    });

    test('should validate YAML with strict mode', () async {
      // Arrange
      const filePath = '/test/strict.yaml';
      const yamlContent = '''
name: test
 value: 123  # Invalid indentation (odd number of spaces)
''';

      await helper.createTestFile(filePath, yamlContent);

      final resourceModel =
          helper.createTestResource(source: filePath, destination: '', actions: [
        Action(type: 'validate', properties: {'format': 'yaml', 'strictMode': true})
      ]);

      final module = FileValidateModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act & Assert
      expect(() async => await module(), throwsException);
    });
  });


  group('Checksum Validation', () {
    test('should validate checksum successfully', () async {
      // Arrange
      const filePath = '/test/checksum.txt';
      const content = 'Hello, World!';
      const expectedChecksum = 'dffd6021bb2bd5b0af676290809ec3a53191dd81c7f70a4b28688a362182986f';

      await helper.createTestFile(filePath, content);

      final resourceModel =
          helper.createTestResource(source: filePath, destination: '', actions: [
        Action(type: 'validate', properties: {'checksum': expectedChecksum})
      ]);

      final module = FileValidateModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act & Assert
      expect(() async => await module(), returnsNormally);
    });

    test('should fail on incorrect checksum', () async {
      // Arrange
      const filePath = '/test/checksum.txt';
      const content = 'Hello, World!';
      const incorrectChecksum = 'incorrect_checksum';

      await helper.createTestFile(filePath, content);

      final resourceModel =
          helper.createTestResource(source: filePath, destination: '', actions: [
        Action(type: 'validate', properties: {'checksum': incorrectChecksum})
      ]);

      final module = FileValidateModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act & Assert
      expect(() async => await module(), throwsException);
    });
  });

  group('Schema Validation', () {
    test('should validate JSON against schema successfully', () async {
      // Arrange
      const filePath = '/test/data.json';
      const schemaPath = '/test/schema.json';
      const jsonContent = '{"name": "test", "value": 123}';
      const schemaContent = '''
{
  "name": {"required": true},
  "value": {"required": true}
}
''';

      await helper.createTestFile(filePath, jsonContent);
      await helper.createTestFile(schemaPath, schemaContent);

      final resourceModel =
          helper.createTestResource(source: filePath, destination: '', actions: [
        Action(type: 'validate', properties: {'format': 'json', 'schema': schemaPath})
      ]);

      final module = FileValidateModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act & Assert
      expect(() async => await module(), returnsNormally);
    });

    test('should fail JSON schema validation for missing required key', () async {
      // Arrange
      const filePath = '/test/data.json';
      const schemaPath = '/test/schema.json';
      const jsonContent = '{"name": "test"}'; // Missing 'value' key
      const schemaContent = '''
{
  "name": {"required": true},
  "value": {"required": true}
}
''';

      await helper.createTestFile(filePath, jsonContent);
      await helper.createTestFile(schemaPath, schemaContent);

      final resourceModel =
          helper.createTestResource(source: filePath, destination: '', actions: [
        Action(type: 'validate', properties: {'format': 'json', 'schema': schemaPath})
      ]);

      final module = FileValidateModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act & Assert
      expect(() async => await module(), throwsException);
    });

    test('should validate YAML against schema successfully', () async {
      // Arrange
      const filePath = '/test/data.yaml';
      const schemaPath = '/test/schema.yaml';
      const yamlContent = '''
name: test
value: 123
''';
      const schemaContent = '''
name:
value:
''';

      await helper.createTestFile(filePath, yamlContent);
      await helper.createTestFile(schemaPath, schemaContent);

      final resourceModel =
          helper.createTestResource(source: filePath, destination: '', actions: [
        Action(type: 'validate', properties: {'format': 'yaml', 'schema': schemaPath})
      ]);

      final module = FileValidateModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act & Assert
      expect(() async => await module(), returnsNormally);
    });
  });

  group('Custom Rules Validation', () {
    group('Contains Rules', () {
      test('should validate contains:must rule successfully', () async {
        // Arrange
        const filePath = '/test/contains_must.txt';
        const content = 'This file contains the required text.';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': ['contains:must:required']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), returnsNormally);
      });

      test('should fail contains:must rule when text not found', () async {
        // Arrange
        const filePath = '/test/contains_must_fail.txt';
        const content = 'This file does not have the required text.';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': ['contains:must:missing']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), throwsException);
      });

      test('should validate contains:mustnot rule successfully', () async {
        // Arrange
        const filePath = '/test/contains_mustnot.txt';
        const content = 'This file is clean and safe.';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': ['contains:mustnot:forbidden']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), returnsNormally);
      });

      test('should fail contains:mustnot rule when forbidden text found', () async {
        // Arrange
        const filePath = '/test/contains_mustnot_fail.txt';
        const content = 'This file contains forbidden content.';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': ['contains:mustnot:forbidden']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), throwsException);
      });

      test('should handle case-sensitive contains rules', () async {
        // Arrange
        const filePath = '/test/contains_case.txt';
        const content = 'This file has UPPERCASE text.';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': ['contains:must:UPPERCASE']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), returnsNormally);
      });

      test('should handle multiple contains rules', () async {
        // Arrange
        const filePath = '/test/contains_multiple.txt';
        const content = 'This file has both required and optional text.';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': ['contains:must:required', 'contains:must:optional']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), returnsNormally);
      });
    });

    group('Regex Rules', () {
      test('should validate regex:must rule successfully', () async {
        // Arrange
        const filePath = '/test/regex_must.txt';
        const content = 'Email: user@example.com';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': [r'regex:must:.*@.*\.com']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), returnsNormally);
      });

      test('should fail regex:must rule when pattern not found', () async {
        // Arrange
        const filePath = '/test/regex_must_fail.txt';
        const content = 'This is not an email address.';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': [r'regex:must:.*@.*\.com']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), throwsException);
      });

      test('should validate regex:mustnot rule successfully', () async {
        // Arrange
        const filePath = '/test/regex_mustnot.txt';
        const content = 'This file is clean without any spam.';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': [r'regex:mustnot:.*@spam\..*']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), returnsNormally);
      });

      test('should fail regex:mustnot rule when forbidden pattern found', () async {
        // Arrange
        const filePath = '/test/regex_mustnot_fail.txt';
        const content = 'Contact: admin@spam.com';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': [r'regex:mustnot:.*@spam\..*']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), throwsException);
      });

      test('should validate complex regex patterns', () async {
        // Arrange
        const filePath = '/test/regex_complex.txt';
        const content = '1.2.3-beta.1';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': [r'regex:must:^\d+\.\d+\.\d+.*']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), returnsNormally);
      });

      test('should validate phone number regex', () async {
        // Arrange
        const filePath = '/test/regex_phone.txt';
        const content = 'Phone: (555) 123-4567';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': [r'regex:must:\(\d{3}\)\s\d{3}-\d{4}']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), returnsNormally);
      });
    });

    group('Length Rules', () {
      test('should validate length:min rule successfully', () async {
        // Arrange
        const filePath = '/test/length_min.txt';
        const content = 'This is a longer text that meets the minimum length requirement.';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': ['length:min:50']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), returnsNormally);
      });

      test('should fail length:min rule when too short', () async {
        // Arrange
        const filePath = '/test/length_min_fail.txt';
        const content = 'Short text.';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': ['length:min:50']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), throwsException);
      });

      test('should validate length:max rule successfully', () async {
        // Arrange
        const filePath = '/test/length_max.txt';
        const content = 'Short text.';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': ['length:max:50']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), returnsNormally);
      });

      test('should fail length:max rule when too long', () async {
        // Arrange
        const filePath = '/test/length_max_fail.txt';
        const content = 'This is a very long text that exceeds the maximum length requirement and should fail validation.';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': ['length:max:50']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), throwsException);
      });

      test('should validate length:exact rule successfully', () async {
        // Arrange
        const filePath = '/test/length_exact.txt';
        const content = 'Exactly 18 chars!!';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': ['length:exact:18']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), returnsNormally);
      });

      test('should fail length:exact rule when not exact length', () async {
        // Arrange
        const filePath = '/test/length_exact_fail.txt';
        const content = 'Not exactly 20 characters.';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': ['length:exact:20']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), throwsException);
      });

      test('should validate multiple length rules', () async {
        // Arrange
        const filePath = '/test/length_multiple.txt';
        const content = 'This text is between 20 and 100 characters long.';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': ['length:min:20', 'length:max:100']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), returnsNormally);
      });
    });

    group('Lines Rules', () {
      test('should validate lines:min rule successfully', () async {
        // Arrange
        const filePath = '/test/lines_min.txt';
        const content = '''Line 1
Line 2
Line 3
Line 4
Line 5''';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': ['lines:min:3']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), returnsNormally);
      });

      test('should fail lines:min rule when too few lines', () async {
        // Arrange
        const filePath = '/test/lines_min_fail.txt';
        const content = '''Line 1
Line 2''';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': ['lines:min:5']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), throwsException);
      });

      test('should validate lines:max rule successfully', () async {
        // Arrange
        const filePath = '/test/lines_max.txt';
        const content = '''Line 1
Line 2
Line 3''';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': ['lines:max:5']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), returnsNormally);
      });

      test('should fail lines:max rule when too many lines', () async {
        // Arrange
        const filePath = '/test/lines_max_fail.txt';
        const content = '''Line 1
Line 2
Line 3
Line 4
Line 5
Line 6''';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': ['lines:max:3']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), throwsException);
      });

      test('should validate lines:exact rule successfully', () async {
        // Arrange
        const filePath = '/test/lines_exact.txt';
        const content = '''Line 1
Line 2
Line 3''';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': ['lines:exact:3']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), returnsNormally);
      });

      test('should fail lines:exact rule when not exact line count', () async {
        // Arrange
        const filePath = '/test/lines_exact_fail.txt';
        const content = '''Line 1
Line 2''';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': ['lines:exact:3']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), throwsException);
      });

      test('should handle empty lines correctly', () async {
        // Arrange
        const filePath = '/test/lines_empty.txt';
        const content = '''Line 1

Line 3

Line 5''';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': ['lines:exact:5']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), returnsNormally);
      });

      test('should validate multiple lines rules', () async {
        // Arrange
        const filePath = '/test/lines_multiple.txt';
        const content = '''Line 1
Line 2
Line 3
Line 4''';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': ['lines:min:2', 'lines:max:10']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), returnsNormally);
      });
    });

    group('Mixed Rules', () {
      test('should validate mixed rule types successfully', () async {
        // Arrange
        const filePath = '/test/mixed_rules.txt';
        const content = '''This file contains version 1.2.3
Email: user@example.com
Phone: (555) 123-4567
This is a longer text that meets all requirements.''';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': [
              'contains:must:version',
              r'regex:must:.*@.*\.com',
              r'regex:must:\(\d{3}\)\s\d{3}-\d{4}',
              'length:min:50',
              'lines:min:3'
            ]
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), returnsNormally);
      });

      test('should fail when any mixed rule fails', () async {
        // Arrange
        const filePath = '/test/mixed_rules_fail.txt';
        const content = '''This file contains version 1.2.3
Email: user@example.com
This is a longer text that meets most requirements.''';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': [
              'contains:must:version',
              r'regex:must:.*@.*\.com',
              r'regex:must:\(\d{3}\)\s\d{3}-\d{4}', // This will fail - no phone number
              'length:min:50',
              'lines:min:3'
            ]
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), throwsException);
      });

      test('should validate complex mixed rules', () async {
        // Arrange
        const filePath = '/test/complex_mixed.txt';
        const content = '''# Configuration File
version: 2.1.0
author: John Doe
email: john@company.com
description: This is a comprehensive configuration file
that contains all necessary settings and parameters
for the application to function correctly.

# Database Settings
database:
  host: localhost
  port: 5432
  name: myapp

# API Settings
api:
  base_url: https://api.example.com
  timeout: 30
  retries: 3''';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': [
              'contains:must:version:',
              'contains:must:author:',
              r'regex:must:.*@.*\.com',
              'contains:mustnot:password',
              'contains:mustnot:secret',
              'length:min:100',
              'lines:min:10',
              'lines:max:50'
            ]
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), returnsNormally);
      });
    });

    group('Edge Cases', () {
      test('should handle empty file with length rules', () async {
        // Arrange
        const filePath = '/test/empty_file.txt';
        const content = '';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': ['length:exact:0']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), returnsNormally);
      });

      test('should handle single line file', () async {
        // Arrange
        const filePath = '/test/single_line.txt';
        const content = 'Single line content';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': ['lines:exact:1', 'contains:must:Single']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), returnsNormally);
      });

      test('should handle special characters in rules', () async {
        // Arrange
        const filePath = '/test/special_chars.txt';
        const content = 'File with special chars: !@#\$%^&*()_+-=[]{}|;:,.<>?';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': ['contains:must:!@#\$%^&*()']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), returnsNormally);
      });

      test('should handle unicode characters', () async {
        // Arrange
        const filePath = '/test/unicode.txt';
        const content = 'File with unicode: 你好世界 🌍 émojis';

        await helper.createTestFile(filePath, content);

        final resourceModel =
            helper.createTestResource(source: filePath, destination: '', actions: [
          Action(type: 'validate', properties: {
            'customRules': ['contains:must:你好世界', 'contains:must:🌍']
          })
        ]);

        final module = FileValidateModule(
            resourceModel, resourceModel.actions.first,
            fileSystem: helper.fileSystem);

        // Act & Assert
        expect(() async => await module(), returnsNormally);
      });
    });
  });

  group('Combined Validation', () {
    test('should validate format, checksum, and custom rules together', () async {
      // Arrange
      const filePath = '/test/combined.json';
      const content = '{"name": "test", "value": 123}';
      const expectedChecksum = 'd8c04bddc717c157fb37ea4db608dd094546ac89461ce1dabbe6a2d899e20e1b';

      await helper.createTestFile(filePath, content);

      final resourceModel =
          helper.createTestResource(source: filePath, destination: '', actions: [
        Action(type: 'validate', properties: {
          'format': 'json',
          'checksum': expectedChecksum,
          'customRules': ['contains:must:name', 'length:min:10']
        })
      ]);

      final module = FileValidateModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act & Assert
      expect(() async => await module(), returnsNormally);
    });
  });

  group('Error Handling', () {
    test('should throw exception for unsupported format', () async {
      // Arrange
      const filePath = '/test/unsupported.txt';
      const content = 'Some content';

      await helper.createTestFile(filePath, content);

      final resourceModel =
          helper.createTestResource(source: filePath, destination: '', actions: [
        Action(type: 'validate', properties: {'format': 'unsupported'})
      ]);

      final module = FileValidateModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act & Assert
      expect(() async => await module(), throwsException);
    });

    test('should throw exception for invalid custom rule format', () async {
      // Arrange
      const filePath = '/test/invalid_rule.txt';
      const content = 'Some content';

      await helper.createTestFile(filePath, content);

      final resourceModel =
          helper.createTestResource(source: filePath, destination: '', actions: [
        Action(type: 'validate', properties: {
          'customRules': ['invalid_rule_format']
        })
      ]);

      final module = FileValidateModule(
          resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act & Assert
      expect(() async => await module(), throwsException);
    });
  });
}
