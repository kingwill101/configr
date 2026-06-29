import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should parse firewalld block with service', () async {
    final blocks = await helper.processConfig('''
      firewalld {
        service = "http"
        zone = "public"
        state = "enabled"
        permanent = true
        immediate = true
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('firewalld'));
    expect(block.service, equals('http'));
    expect(block.zone, equals('public'));
    expect(block.state, equals('enabled'));
    expect(block.permanent, isTrue);
    expect(block.immediate, isTrue);
  });

  test('should parse firewalld block with port', () async {
    final blocks = await helper.processConfig('''
      firewalld {
        port = "8080/tcp"
        zone = "internal"
        state = "enabled"
        rich_rule = "rule family=ipv4 source address=192.168.0.0/24 accept"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.port, equals('8080/tcp'));
    expect(block.zone, equals('internal'));
    expect(block.richRule, contains('192.168.0.0/24'));
  });

  test('should use default values', () async {
    final blocks = await helper.processConfig('''
      firewalld {
        service = "ssh"
        state = "enabled"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.zone, equals('public'));
    expect(block.permanent, isTrue);
    expect(block.immediate, isFalse);
  });

  test('should return correct dry-run summary', () async {
    final blocks = await helper.processConfig('''
      firewalld {
        service = "http"
        state = "enabled"
      }
    ''');

    final block = blocks.first as dynamic;
    expect(
      block.dryRunSummary(),
      equals('firewalld: service=http, state=enabled'),
    );
  });

  test('should return minimal dry-run summary', () async {
    final blocks = await helper.processConfig('''
      firewalld {
        port = "443/tcp"
        state = "disabled"
      }
    ''');

    final block = blocks.first as dynamic;
    expect(
      block.dryRunSummary(),
      equals('firewalld: port=443/tcp, state=disabled'),
    );
  });
}
