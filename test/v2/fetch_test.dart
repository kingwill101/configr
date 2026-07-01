import 'package:configr/src/events/module_events.dart';
import 'package:file/file.dart' show File;
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should parse fetch block properties', () async {
    final blocks = await helper.processConfig('''
      fetch {
        src = "/var/log/syslog"
        dest = "/tmp/backup"
        flat = true
        fail_on_missing = false
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('fetch'));
    expect(block.src, equals('/var/log/syslog'));
    expect(block.dest, equals('/tmp/backup'));
    expect(block.flat, isTrue);
    expect(block.failOnMissing, isFalse);
  });

  test('should use default values', () async {
    final blocks = await helper.processConfig('''
      fetch {
        src = "/var/log/syslog"
        dest = "/tmp/backup"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.flat, isFalse);
    expect(block.failOnMissing, isTrue);
  });

  test('should fail when src is missing', () async {
    await helper.runConfig('''
      fetch {
        dest = "/tmp/backup"
      }
    ''');

    expect(helper.eventOfType<FailedEvent>(), isNotNull);
  });

  test('should fail when dest is missing', () async {
    await helper.runConfig('''
      fetch {
        src = "/var/log/syslog"
      }
    ''');

    expect(helper.eventOfType<FailedEvent>(), isNotNull);
  });

  test('should return correct dry-run summary', () async {
    final blocks = await helper.processConfig('''
      fetch {
        src = "/var/log/syslog"
        dest = "/tmp/backup"
      }
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), startsWith('fetch: /var/log/syslog ->'));
  });

  test('should normalize Windows separators in dry-run target path', () async {
    final blocks = await helper.processConfig(r'''
      fetch {
        src = "C:\\Windows\\System32\\drivers\\etc\\hosts"
        dest = "C:\\configr\\fetch"
      }
    ''');

    final block = blocks.first as dynamic;
    final summary = block.dryRunSummary() as String;
    final target = summary.split(' -> ').last;
    expect(target, contains('C:/configr/fetch/'));
    expect(target, contains('C/Windows/System32/drivers/etc/hosts'));
    expect(target, isNot(contains(r'\')));
  });

  test('should keep Windows drive letters in dry-run target path', () async {
    final blocks = await helper.processConfig(r'''
      fetch {
        src = "D:\\data\\config.json"
        dest = "/tmp/fetch_test"
      }
    ''');

    final block = blocks.first as dynamic;
    final summary = block.dryRunSummary() as String;
    final target = summary.split(' -> ').last;
    expect(target, contains('/tmp/fetch_test/'));
    expect(target, contains('D/data/config.json'));
    expect(target, isNot(contains('D:/data/config.json')));
  });

  test(
    'should keep absolute source paths under destination in non-flat mode',
    () async {
      await helper.createFile('/etc/hostname', 'test-host');

      await helper.runConfig('''
      fetch {
        src = "/etc/hostname"
        dest = "/tmp/fetch_test"
      }
    ''');

      final copiedFiles = helper.fileSystem
          .directory('/tmp/fetch_test')
          .listSync(recursive: true)
          .whereType<File>()
          .where((entry) => entry.path.endsWith('/etc/hostname'))
          .toList();
      expect(copiedFiles, hasLength(1));
      expect(
        await helper.readFile(copiedFiles.single.path),
        equals('test-host'),
      );
    },
  );

  test('should return correct dry-run summary empty', () async {
    final blocks = await helper.processConfig('''
      fetch {}
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('fetch: (empty)'));
  });
}
