import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should create new file when it does not exist', () async {
    const filePath = '/test/newfile.txt';

    await helper.runConfig('''
      touch {
        source = "$filePath"
        create_if_missing = true
      }
    ''');

    expect(await helper.fileExists(filePath), isTrue);
  });

  test('should update modification time of existing file', () async {
    const filePath = '/test/existing.txt';
    await helper.createFile(filePath, 'test content');

    final beforeTime = helper.fileSystem.file(filePath).lastModifiedSync();

    // Wait a moment to ensure modification time will be different
    await Future.delayed(const Duration(milliseconds: 100));

    await helper.runConfig('''
      touch {
        source = "$filePath"
      }
    ''');

    final afterTime = helper.fileSystem.file(filePath).lastModifiedSync();
    expect(afterTime.isAfter(beforeTime), isTrue);
  });

  test(
    'should fail when file does not exist and create_if_missing is false',
    () async {
      const filePath = '/test/nonexistent.txt';

      await helper.runConfig('''
        touch {
          source = "$filePath"
          create_if_missing = false
        }
      ''');

      // File should not have been created
      expect(await helper.fileExists(filePath), isFalse);
      // A FailedEvent should have been emitted
      expect(helper.emittedEvents.any((e) => e is FailedEvent), isTrue);
    },
  );
}
