import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should rename file successfully', () async {
    const sourcePath = '/test/oldname.txt';
    const destPath = '/test/newname.txt';
    const content = 'test content';

    await helper.createFile(sourcePath, content);

    await helper.runConfig('''
      rename {
        source = "$sourcePath"
        destination = "$destPath"
      }
    ''');

    expect(await helper.fileExists(sourcePath), isFalse);
    expect(await helper.fileExists(destPath), isTrue);
    expect(await helper.readFile(destPath), equals(content));
  });

  test('should fail when destination exists and overwrite is false', () async {
    const sourcePath = '/test/source.txt';
    const destPath = '/test/dest.txt';

    await helper.createFile(sourcePath, 'source content');
    await helper.createFile(destPath, 'destination content');

    await helper.runConfig('''
      rename {
        source = "$sourcePath"
        destination = "$destPath"
        overwrite = false
      }
    ''');

    // Source should still exist, destination should keep original content
    expect(await helper.fileExists(sourcePath), isTrue);
    expect(await helper.readFile(destPath), equals('destination content'));
    // A FailedEvent should have been emitted
    expect(helper.emittedEvents.any((e) => e is FailedEvent), isTrue);
  });

  test('should overwrite when configured', () async {
    const sourcePath = '/test/source.txt';
    const destPath = '/test/dest.txt';

    await helper.createFile(sourcePath, 'source content');
    await helper.createFile(destPath, 'destination content');

    await helper.runConfig('''
      rename {
        source = "$sourcePath"
        destination = "$destPath"
        overwrite = true
      }
    ''');

    expect(await helper.fileExists(sourcePath), isFalse);
    expect(await helper.fileExists(destPath), isTrue);
    expect(await helper.readFile(destPath), equals('source content'));
  });

  test('should handle rollback correctly', () async {
    const sourcePath = '/test/source.txt';
    const destPath = '/test/dest.txt';
    const content = 'test content';

    await helper.createFile(sourcePath, content);

    await helper.runConfigWithRollback('''
      rename {
        source = "$sourcePath"
        destination = "$destPath"
      }
    ''');

    expect(await helper.fileExists(sourcePath), isTrue);
    expect(await helper.fileExists(destPath), isFalse);
    expect(await helper.readFile(sourcePath), equals(content));
  });
}
