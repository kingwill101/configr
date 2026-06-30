import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should add line to end of file when no regexp specified', () async {
    await helper.createFile('/test.txt', 'line1\nline2\n');

    await helper.runConfig('''
      lineinfile {
        path = "/test.txt"
        line = "newline"
      }
    ''');

    final content = await helper.readFile('/test.txt');
    expect(content, contains('line1'));
    expect(content, contains('line2'));
    expect(content, contains('newline'));
  });

  test('should replace line matching regexp', () async {
    await helper.createFile('/test.txt', 'old_value\nother_line\n');

    await helper.runConfig('''
      lineinfile {
        path = "/test.txt"
        regexp = "old.*"
        line = "new_value"
      }
    ''');

    final content = await helper.readFile('/test.txt');
    expect(content, contains('new_value'));
    expect(content, isNot(contains('old_value')));
    expect(content, contains('other_line'));
  });

  test('should insert line before matching pattern', () async {
    await helper.createFile('/test.txt', 'first\nsecond\nthird\n');

    await helper.runConfig('''
      lineinfile {
        path = "/test.txt"
        insert_before = "third"
        line = "inserted"
      }
    ''');

    final content = await helper.readFile('/test.txt');
    expect(content, contains('first\nsecond\ninserted\nthird'));
  });

  test('should insert line after matching pattern', () async {
    await helper.createFile('/test.txt', 'first\nsecond\nthird\n');

    await helper.runConfig('''
      lineinfile {
        path = "/test.txt"
        insert_after = "first"
        line = "inserted"
      }
    ''');

    final content = await helper.readFile('/test.txt');
    expect(content, contains('first\ninserted\nsecond'));
  });

  test('should remove line matching regexp when status=absent', () async {
    await helper.createFile('/test.txt', 'keep\nremove_me\nkeep_too\n');

    await helper.runConfig('''
      lineinfile {
        path = "/test.txt"
        regexp = "remove.*"
        state = "absent"
        line = "irrelevant"
      }
    ''');

    final content = await helper.readFile('/test.txt');
    expect(content, isNot(contains('remove_me')));
    expect(content, contains('keep'));
    expect(content, contains('keep_too'));
  });

  test('should create file when create=true and file does not exist', () async {
    await helper.runConfig('''
      lineinfile {
        path = "/newfile.txt"
        line = "first line"
        create = true
      }
    ''');

    expect(await helper.fileExists('/newfile.txt'), isTrue);
    final content = await helper.readFile('/newfile.txt');
    expect(content, contains('first line'));
  });

  test('should fail when create=false and file does not exist', () async {
    await helper.runConfig('''
      lineinfile {
        path = "/nonexistent.txt"
        line = "fail"
      }
    ''');

    expect(helper.emittedEvents.any((e) => e is FailedEvent), isTrue);
  });

  test('should backup file before edit when backup=true', () async {
    await helper.createFile('/test.txt', 'original\n');

    await helper.runConfig('''
      lineinfile {
        path = "/test.txt"
        regexp = "original"
        line = "modified"
        backup = true
      }
    ''');

    expect(await helper.fileExists('/test.txt.bak'), isTrue);
    expect(await helper.readFile('/test.txt.bak'), contains('original'));
  });

  test('should restore backup on rollback', () async {
    await helper.createFile('/test.txt', 'original\n');

    await helper.runConfigWithRollback('''
      lineinfile {
        path = "/test.txt"
        regexp = "original"
        line = "modified"
        backup = true
      }
    ''');

    expect(await helper.readFile('/test.txt'), contains('original'));
    expect(await helper.fileExists('/test.txt.bak'), isFalse);
  });

  test('should fail when path is not specified', () async {
    await helper.runConfig('''
      lineinfile {
        line = "fail"
      }
    ''');

    expect(helper.emittedEvents.any((e) => e is FailedEvent), isTrue);
  });

  test('should be idempotent', () async {
    await helper.createFile('/test.txt', 'line1\n');

    await helper.runConfig('''
      lineinfile {
        path = "/test.txt"
        regexp = "line1"
        line = "replaced"
      }
    ''');

    await helper.runConfig('''
      lineinfile {
        path = "/test.txt"
        regexp = "line1"
        line = "replaced"
      }
    ''');

    final content = await helper.readFile('/test.txt');
    expect('replaced\n'.allMatches(content).length, equals(1));
  });

  test('should replace all matching lines', () async {
    await helper.createFile('/test.txt', 'foo\nbar\nfoo\nbaz\n');

    await helper.runConfig('''
      lineinfile {
        path = "/test.txt"
        regexp = "foo"
        line = "replaced"
      }
    ''');

    final content = await helper.readFile('/test.txt');
    expect('replaced'.allMatches(content).length, equals(1));
  });
}
