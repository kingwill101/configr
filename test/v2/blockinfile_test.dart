import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should insert block into file', () async {
    await helper.createFile('/test.txt', 'line1\nline2\n');

    await helper.runConfig('''
      blockinfile {
        path = "/test.txt"
        block = "managed content"
      }
    ''');

    final content = await helper.readFile('/test.txt');
    expect(content, contains('BEGIN CONFIGR MANAGED BLOCK'));
    expect(content, contains('managed content'));
    expect(content, contains('END CONFIGR MANAGED BLOCK'));
  });

  test('should replace existing block with same marker', () async {
    const initialContent = 'preamble\n# BEGIN CONFIGR MANAGED BLOCK\nold\n'
        '# END CONFIGR MANAGED BLOCK\npostamble\n';
    await helper.createFile('/test.txt', initialContent);

    await helper.runConfig('''
      blockinfile {
        path = "/test.txt"
        block = "new content"
      }
    ''');

    final content = await helper.readFile('/test.txt');
    expect(content, contains('new content'));
    expect(content, isNot(contains('old')));
    expect(content, contains('preamble'));
    expect(content, contains('postamble'));
  });

  test('should remove block when status=absent', () async {
    const initialContent = 'preamble\n# BEGIN CONFIGR MANAGED BLOCK\n'
        'managed\n# END CONFIGR MANAGED BLOCK\npostamble\n';
    await helper.createFile('/test.txt', initialContent);

    await helper.runConfig('''
      blockinfile {
        path = "/test.txt"
        block = "managed"
        state = "absent"
      }
    ''');

    final content = await helper.readFile('/test.txt');
    expect(content, isNot(contains('ANISBLE MANAGED BLOCK')));
    expect(content, contains('preamble'));
    expect(content, contains('postamble'));
  });

  test('should create file when create=true and file does not exist', () async {
    await helper.runConfig('''
      blockinfile {
        path = "/newfile.txt"
        block = "managed content"
        create = true
      }
    ''');

    expect(await helper.fileExists('/newfile.txt'), isTrue);
    final content = await helper.readFile('/newfile.txt');
    expect(content, contains('managed content'));
  });

  test('should fail when create=false and file does not exist', () async {
    await helper.runConfig('''
      blockinfile {
        path = "/nonexistent.txt"
        block = "fail"
      }
    ''');

    expect(helper.emittedEvents.any((e) => e is FailedEvent), isTrue);
  });

  test('should backup file when backup=true', () async {
    await helper.createFile('/test.txt', 'original\n');

    await helper.runConfig('''
      blockinfile {
        path = "/test.txt"
        block = "managed"
        backup = true
      }
    ''');

    expect(await helper.fileExists('/test.txt.bak'), isTrue);
    expect(await helper.readFile('/test.txt.bak'), contains('original'));
  });

  test('should restore backup on rollback', () async {
    await helper.createFile('/test.txt', 'original\n');

    await helper.runConfigWithRollback('''
      blockinfile {
        path = "/test.txt"
        block = "managed"
        backup = true
      }
    ''');

    expect(await helper.readFile('/test.txt'), equals('original\n'));
    expect(await helper.fileExists('/test.txt.bak'), isFalse);
  });

  test('should use custom marker', () async {
    await helper.createFile('/test.txt', 'line1\n');

    await helper.runConfig('''
      blockinfile {
        path = "/test.txt"
        marker = "# CUSTOM {mark}"
        block = "custom content"
      }
    ''');

    final content = await helper.readFile('/test.txt');
    expect(content, contains('# CUSTOM BEGIN'));
    expect(content, contains('custom content'));
    expect(content, contains('# CUSTOM END'));
  });

  test('should be idempotent', () async {
    await helper.createFile('/test.txt', 'line1\n');

    await helper.runConfig('''
      blockinfile {
        path = "/test.txt"
        block = "content"
      }
    ''');

    await helper.runConfig('''
      blockinfile {
        path = "/test.txt"
        block = "content"
      }
    ''');

    final content = await helper.readFile('/test.txt');
    final beginMatches = 'BEGIN CONFIGR MANAGED BLOCK'.allMatches(content).length;
    expect(beginMatches, equals(1));
  });

  test('should fail when path is not specified', () async {
    await helper.runConfig('''
      blockinfile {
        block = "fail"
      }
    ''');

    expect(helper.emittedEvents.any((e) => e is FailedEvent), isTrue);
  });
}
