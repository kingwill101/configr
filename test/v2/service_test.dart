import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should parse service block properties', () async {
    final blocks = await helper.processConfig('''
      service {
        name = "nginx"
        state = "started"
        enabled = true
        use = "systemd"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('service'));
    expect(block.name, equals('nginx'));
    expect(block.state, equals('started'));
    expect(block.enabled, isTrue);
    expect(block.use, equals('systemd'));
  });

  test('should use default values', () async {
    final blocks = await helper.processConfig('''
      service {
        name = "nginx"
        state = "started"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.name, equals('nginx'));
    expect(block.enabled, isFalse);
    expect(block.use, equals('auto'));
  });

  test('should return correct dry-run summary', () async {
    final blocks = await helper.processConfig('''
      service {
        name = "docker"
        state = "started"
        enabled = true
      }
    ''');

    final block = blocks.first as dynamic;
    expect(
      block.dryRunSummary(),
      equals('service: docker, state=started, enabled'),
    );
  });

  test('should return minimal dry-run summary', () async {
    final blocks = await helper.processConfig('''
      service {
        name = "cron"
        state = "stopped"
      }
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('service: cron, state=stopped'));
  });
}
