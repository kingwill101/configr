import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should move file successfully', () async {
    const sourcePath = '/source/test.txt';
    const destPath = '/dest/test.txt';
    const content = 'test content';

    await helper.createFile(sourcePath, content);

    await helper.runConfig('''
      move {
        source = "$sourcePath"
        destination = "$destPath"
      }
    ''');

    expect(await helper.fileExists(sourcePath), isFalse);
    expect(await helper.fileExists(destPath), isTrue);
    expect(await helper.readFile(destPath), equals(content));
  });

  test('should create destination directory if needed', () async {
    const sourcePath = '/source/test.txt';
    const destPath = '/dest/subdir/test.txt';
    const content = 'test content';

    await helper.createFile(sourcePath, content);

    await helper.runConfig('''
      move {
        source = "$sourcePath"
        destination = "$destPath"
      }
    ''');

    expect(await helper.fileExists(sourcePath), isFalse);
    expect(await helper.fileExists(destPath), isTrue);
  });

  test('should handle rollback correctly', () async {
    const sourcePath = '/source/test.txt';
    const destPath = '/dest/test.txt';
    const content = 'test content';

    await helper.createFile(sourcePath, content);

    await helper.runConfigWithRollback('''
      move {
        source = "$sourcePath"
        destination = "$destPath"
      }
    ''');

    expect(await helper.fileExists(sourcePath), isTrue);
    expect(await helper.fileExists(destPath), isFalse);
    expect(await helper.readFile(sourcePath), equals(content));
  });

  test('should fail when source does not exist', () async {
    const sourcePath = '/nonexistent/source.txt';
    const destPath = '/dest/test.txt';

    await helper.runConfig('''
      move {
        source = "$sourcePath"
        destination = "$destPath"
      }
    ''');

    // Target file should not have been created
    expect(await helper.fileExists(destPath), isFalse);
    // A FailedEvent should have been emitted
    expect(helper.emittedEvents.any((e) => e is FailedEvent), isTrue);
  });
}
