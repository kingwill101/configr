import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should parse wait_for block with port', () async {
    final blocks = await helper.processConfig('''
      wait_for {
        host = "localhost"
        port = 8080
        timeout = 30
        delay = 5
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('wait_for'));
    expect(block.host, equals('localhost'));
    expect(block.port, equals(8080));
    expect(block.timeout, equals(30));
    expect(block.delay, equals(5));
    expect(block.activeConnection, isFalse);
  });

  test('should parse wait_for block with path and search_regex', () async {
    final blocks = await helper.processConfig('''
      wait_for {
        path = "/var/log/app.log"
        search_regex = "started"
        timeout = 60
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.path, equals('/var/log/app.log'));
    expect(block.searchRegex, equals('started'));
    expect(block.timeout, equals(60));
  });

  test('should use default values', () async {
    final blocks = await helper.processConfig('''
      wait_for {
        path = "/tmp/ready"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.timeout, equals(300));
    expect(block.delay, equals(0));
    expect(block.sleep, isFalse);
    expect(block.excludeHosts, isFalse);
  });

  test('should fail when condition not met', () async {
    await helper.runConfig('''
      wait_for {
        path = "/nonexistent/file.txt"
        timeout = 1
      }
    ''');

    expect(helper.eventOfType<FailedEvent>(), isNotNull);
  });

  test('should succeed when path exists', () async {
    await helper.createFile('/tmp/ready.txt', 'ready');

    final blocks = await helper.runConfig('''
      wait_for {
        path = "/tmp/ready.txt"
        timeout = 5
      }
    ''');

    expect(blocks, hasLength(1));
    expect(helper.eventOfType<CompletedEvent>(), isNotNull);
  });

  test('should succeed when file content matches search_regex', () async {
    await helper.createFile(
      '/var/log/app.log',
      '[INFO] Application started successfully\n',
    );

    final blocks = await helper.runConfig('''
      wait_for {
        path = "/var/log/app.log"
        search_regex = "started"
        timeout = 5
      }
    ''');

    expect(blocks, hasLength(1));
    expect(helper.eventOfType<CompletedEvent>(), isNotNull);
  });

  test('should fail when file content does not match search_regex', () async {
    await helper.createFile('/var/log/app.log', '[INFO] Loading...\n');

    await helper.runConfig('''
      wait_for {
        path = "/var/log/app.log"
        search_regex = "started"
        timeout = 1
      }
    ''');

    expect(helper.eventOfType<FailedEvent>(), isNotNull);
  });

  test('should fail when host, port, and path are all empty', () async {
    await helper.runConfig('''
      wait_for {
        timeout = 1
      }
    ''');

    expect(helper.eventOfType<FailedEvent>(), isNotNull);
  });

  test('should return correct dry-run summary with port', () async {
    final blocks = await helper.processConfig('''
      wait_for {
        host = "db.example.com"
        port = 5432
      }
    ''');

    final block = blocks.first as dynamic;
    expect(
      block.dryRunSummary(),
      equals('wait_for: db.example.com:5432 (timeout=300)'),
    );
  });

  test('should return correct dry-run summary with path', () async {
    final blocks = await helper.processConfig('''
      wait_for {
        path = "/tmp/ready"
      }
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('wait_for: /tmp/ready (timeout=300)'));
  });
}
