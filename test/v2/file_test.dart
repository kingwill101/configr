import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should initialize with default values', () async {
    const filePath = '/test/file.txt';

    final blocks = await helper.processConfig('''
      file {
        source = "$filePath"
        content = "Hello, World!"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first;
    expect((block as dynamic).operation, equals('create'));
    expect((block as dynamic).createDirectories, isTrue);
  });

  test('should create file successfully', () async {
    const filePath = '/test/create_test.txt';

    await helper.runConfig('''
      file {
        source = "$filePath"
        destination = "$filePath"
        content = "Created by test"
        operation = "create"
        create_directories = true
      }
    ''');

    expect(await helper.fileExists(filePath), isTrue);
    expect(await helper.readFile(filePath), equals('Created by test'));
  });

  test('should update state with configuration', () async {
    const filePath = '/test/config_test.txt';

    final blocks = await helper.processConfig('''
      file {
        source = "$filePath"
        destination = "$filePath"
        content = "Test content"
        operation = "create"
        edit_mode = "append"
        file_path = "$filePath"
        create_directories = true
        backup_original = true
        backup_suffix = ".bak"
      }
    ''');

    final block = blocks.first;
    expect((block as dynamic).operation, equals('create'));
    expect((block as dynamic).content, equals('Test content'));
    expect((block as dynamic).editMode, equals('append'));
    expect((block as dynamic).backupOriginal, isTrue);
    expect((block as dynamic).backupSuffix, equals('.bak'));
  });

  test('should edit file in replace mode', () async {
    const filePath = '/test/edit_replace.txt';
    await helper.createFile(filePath, 'Original content');

    await helper.runConfig('''
      file {
        source = "$filePath"
        destination = "$filePath"
        content = "Replaced content"
        operation = "edit"
        edit_mode = "replace"
      }
    ''');

    expect(await helper.readFile(filePath), equals('Replaced content'));
  });

  test('should edit file in append mode', () async {
    const filePath = '/test/edit_append.txt';
    await helper.createFile(filePath, 'Original content\n');

    await helper.runConfig('''
      file {
        source = "$filePath"
        destination = "$filePath"
        content = "Appended content"
        operation = "edit"
        edit_mode = "append"
      }
    ''');

    final content = await helper.readFile(filePath);
    expect(content, contains('Original content'));
    expect(content, contains('Appended content'));
  });

  test('should remove file', () async {
    const filePath = '/test/remove_me.txt';
    await helper.createFile(filePath, 'delete me');

    await helper.runConfig('''
      file {
        source = "$filePath"
        destination = "$filePath"
        operation = "remove"
      }
    ''');

    expect(await helper.fileExists(filePath), isFalse);
  });
}
