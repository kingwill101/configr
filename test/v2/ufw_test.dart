import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should parse ufw block with port rule', () async {
    final blocks = await helper.processConfig('''
      ufw {
        rule = "allow"
        port = "80"
        proto = "tcp"
        direction = "in"
        state = "enabled"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('ufw'));
    expect(block.rule, equals('allow'));
    expect(block.port, equals('80'));
    expect(block.proto, equals('tcp'));
    expect(block.direction, equals('in'));
    expect(block.state, equals('enabled'));
  });

  test('should parse ufw block with from/to', () async {
    final blocks = await helper.processConfig('''
      ufw {
        rule = "deny"
        from = "10.0.0.0/8"
        to = "any"
        interface = "eth0"
        log = "low"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.rule, equals('deny'));
    expect(block.from, equals('10.0.0.0/8'));
    expect(block.to, equals('any'));
    expect(block.interface, equals('eth0'));
    expect(block.log, equals('low'));
  });

  test('should use default values', () async {
    final blocks = await helper.processConfig('''
      ufw {
        rule = "allow"
        port = "22"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.rule, equals('allow'));
    expect(block.port, equals('22'));
    expect(block.proto, isEmpty);
    expect(block.direction, isEmpty);
    expect(block.state, isEmpty);
  });

  test('should return correct dry-run summary', () async {
    final blocks = await helper.processConfig('''
      ufw {
        rule = "allow"
        port = "443"
        proto = "tcp"
      }
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('ufw: rule=allow, port=443, proto=tcp'));
  });

  test('should return minimal dry-run summary', () async {
    final blocks = await helper.processConfig('''
      ufw {}
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), isEmpty);
  });
}
