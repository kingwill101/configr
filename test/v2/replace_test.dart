import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should replace regex pattern in file', () async {
    await helper.createFile('/test.txt', 'hello world\nfoo bar\n');

    await helper.runConfig('''
      replace {
        path = "/test.txt"
        regexp = "world"
        replace = "universe"
      }
    ''');

    final content = await helper.readFile('/test.txt');
    expect(content, contains('hello universe'));
    expect(content, contains('foo bar'));
  });

  test('should replace after matching line', () async {
    await helper.createFile('/test.txt', 'before\nsection\nold_value\nend\n');

    await helper.runConfig('''
      replace {
        path = "/test.txt"
        after = "section"
        regexp = "old"
        replace = "new"
      }
    ''');

    final content = await helper.readFile('/test.txt');
    expect(content, contains('before'));
    expect(content, contains('section'));
    expect(content, contains('new_value'));
    expect(content, contains('end'));
  });

  test('should replace before matching line', () async {
    await helper.createFile('/test.txt', 'old_value\nsection\nend\n');

    await helper.runConfig('''
      replace {
        path = "/test.txt"
        before = "end"
        regexp = "old"
        replace = "new"
      }
    ''');

    final content = await helper.readFile('/test.txt');
    expect(content, contains('new_value'));
    expect(content, contains('section'));
    expect(content, contains('end'));
  });

  // Note: this test demonstrates that `before` excludes the match line
  test('should not modify content after before match', () async {
    await helper.createFile('/test.txt', 'old\nold_before\nmarker\nold_after\n');

    await helper.runConfig('''
      replace {
        path = "/test.txt"
        before = "marker"
        regexp = "old"
        replace = "new"
      }
    ''');

    final content = await helper.readFile('/test.txt');
    expect(content, contains('new'));
    expect(content, contains('new_before'));
    expect(content, contains('marker'));
    expect(content, contains('old_after'));
  });

  test('should fail when file does not exist', () async {
    await helper.runConfig('''
      replace {
        path = "/nonexistent.txt"
        regexp = "old"
        replace = "new"
      }
    ''');

    expect(helper.emittedEvents.any((e) => e is FailedEvent), isTrue);
  });

  test('should backup file when backup=true', () async {
    await helper.createFile('/test.txt', 'original\n');

    await helper.runConfig('''
      replace {
        path = "/test.txt"
        regexp = "original"
        replace = "modified"
        backup = true
      }
    ''');

    expect(await helper.fileExists('/test.txt.bak'), isTrue);
    expect(await helper.readFile('/test.txt.bak'), contains('original'));
  });

  test('should restore backup on rollback', () async {
    await helper.createFile('/test.txt', 'original\n');

    await helper.runConfigWithRollback('''
      replace {
        path = "/test.txt"
        regexp = "original"
        replace = "modified"
        backup = true
      }
    ''');

    expect(await helper.readFile('/test.txt'), contains('original'));
    expect(await helper.fileExists('/test.txt.bak'), isFalse);
  });

  test('should fail when path is not specified', () async {
    await helper.runConfig('''
      replace {
        regexp = "old"
        replace = "new"
      }
    ''');

    expect(helper.emittedEvents.any((e) => e is FailedEvent), isTrue);
  });

  test('should replace multiple occurrences', () async {
    await helper.createFile('/test.txt', 'foo\nfoo\nbar\n');

    await helper.runConfig('''
      replace {
        path = "/test.txt"
        regexp = "foo"
        replace = "replaced"
      }
    ''');

    final content = await helper.readFile('/test.txt');
    expect('replaced'.allMatches(content).length, equals(2));
  });

  test('should be idempotent', () async {
    await helper.createFile('/test.txt', 'old_value\n');

    await helper.runConfig('''
      replace {
        path = "/test.txt"
        regexp = "old"
        replace = "new"
      }
    ''');

    await helper.runConfig('''
      replace {
        path = "/test.txt"
        regexp = "old"
        replace = "new"
      }
    ''');

    final content = await helper.readFile('/test.txt');
    expect('new'.allMatches(content).length, equals(1));
  });
}
