import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should parse unarchive block properties', () async {
    final blocks = await helper.processConfig('''
      unarchive {
        src = "/tmp/archive.tar.gz"
        dest = "/opt/app"
        remote_src = true
        format = "gzip"
        list_files = true
        creates = "/opt/app/.deployed"
        extra_opts = "--strip-components=1"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('unarchive'));
    expect(block.src, equals('/tmp/archive.tar.gz'));
    expect(block.dest, equals('/opt/app'));
    expect(block.remoteSrc, isTrue);
    expect(block.format, equals('gzip'));
    expect(block.listFiles, isTrue);
    expect(block.creates, equals('/opt/app/.deployed'));
    expect(block.extraOpts, equals('--strip-components=1'));
  });

  test('should use default values', () async {
    final blocks = await helper.processConfig('''
      unarchive {
        src = "/tmp/archive.tar.gz"
        dest = "/opt/app"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.src, equals('/tmp/archive.tar.gz'));
    expect(block.dest, equals('/opt/app'));
    expect(block.remoteSrc, isFalse);
    expect(block.format, equals('auto'));
    expect(block.listFiles, isFalse);
    expect(block.creates, isEmpty);
  });

  test('should fail when src is missing', () async {
    await helper.runConfig('''
      unarchive {
        dest = "/opt/app"
      }
    ''');

    expect(helper.eventOfType<FailedEvent>(), isNotNull);
  });

  test('should fail when dest is missing', () async {
    await helper.runConfig('''
      unarchive {
        src = "/tmp/archive.tar.gz"
      }
    ''');

    expect(helper.eventOfType<FailedEvent>(), isNotNull);
  });

  test('should skip when creates path exists', () async {
    await helper.createFile('/opt/app/.deployed', '');

    final blocks = await helper.runConfig('''
      unarchive {
        src = "/tmp/archive.tar.gz"
        dest = "/opt/app"
        creates = "/opt/app/.deployed"
      }
    ''');

    expect(blocks, hasLength(1));
    expect(helper.eventOfType<StatusUpdateEvent>(), isNotNull);
  });

  test('should return correct dry-run summary', () async {
    final blocks = await helper.processConfig('''
      unarchive {
        src = "/tmp/archive.zip"
        dest = "/opt/data"
      }
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('unarchive: /tmp/archive.zip -> /opt/data'));
  });

  test('should return correct dry-run summary empty', () async {
    final blocks = await helper.processConfig('''
      unarchive {}
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('unarchive: (empty)'));
  });
}
