import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should parse stat block properties', () async {
    final blocks = await helper.runConfig('''
      stat {
        path = "/tmp/test.txt"
        follow = true
        checksum_algorithm = "sha256"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('stat'));
    expect(block.path, equals('/tmp/test.txt'));
    expect(block.follow, isTrue);
    expect(block.checksumAlgorithm, equals('sha256'));
  });

  test('should use default values for optional properties', () async {
    final blocks = await helper.runConfig('''
      stat {
        path = "/tmp/test.txt"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('stat'));
    expect(block.follow, isTrue);
    expect(block.checksumAlgorithm, equals('sha256'));
  });

  test('should emit started event during execution', () async {
    helper.clearEvents();
    
    await helper.runConfig('''
      stat {
        path = "/nonexistent/file.txt"
      }
    ''');

    final startedEvent = helper.eventOfType<StartedEvent>();
    expect(startedEvent, isNotNull);
    expect(startedEvent!.message, contains('Stat'));
  });

  test('should set stat variables on context for existing file', () async {
    await helper.createFile('/tmp/test_stat.txt', 'test content');
    
    final blocks = await helper.runConfig('''
      stat {
        path = "/tmp/test_stat.txt"
      }
    ''');
    expect(blocks, hasLength(1));
  });

  test('should return correct dry-run summary', () async {
    final blocks = await helper.processConfig('''
      stat {
        path = "/tmp/test.txt"
      }
    ''');

    final block = blocks.first as dynamic;
    final summary = block.dryRunSummary();
    expect(summary, equals('stat: path=/tmp/test.txt'));
  });

  test('should return empty summary when no path', () async {
    final blocks = await helper.processConfig('''
      stat {}
    ''');

    final block = blocks.first as dynamic;
    final summary = block.dryRunSummary();
    expect(summary, equals('stat: (empty)'));
  });
}