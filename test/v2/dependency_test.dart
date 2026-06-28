import 'package:configr/src/blocks/dependency_block.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should parse host and check_type properties', () async {
    final blocks = await helper.processConfig('''
      dependency {
        host = "192.168.1.1"
        type = "network"
        state = "reachable"
        timeout = 10
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as DependencyBlock;
    expect(block.blockType, equals('dependency'));
    expect(block.host, equals('192.168.1.1'));
    expect(block.checkType, equals('network'));
    expect(block.state, equals('reachable'));
    expect(block.timeout, equals(10));
  });

  test('should parse to and port properties', () async {
    final blocks = await helper.processConfig('''
      dependency {
        to = "db-01"
        port = 5432
        type = "port"
        timeout = 30
      }
    ''');

    final block = blocks.first as DependencyBlock;
    expect(block.to, equals('db-01'));
    expect(block.port, equals(5432));
    expect(block.checkType, equals('port'));
    expect(block.timeout, equals(30));
  });

  test('should parse from property', () async {
    final blocks = await helper.processConfig('''
      dependency {
        from = "web-01"
        to = "db-01"
        type = "ping"
        interval = 10
        delay = 2
      }
    ''');

    final block = blocks.first as DependencyBlock;
    expect(block.from, equals('web-01'));
    expect(block.to, equals('db-01'));
    expect(block.interval, equals(10));
    expect(block.delay, equals(2));
  });

  test('should use default values when not specified', () async {
    final blocks = await helper.processConfig('''
      dependency {
        host = "10.0.0.1"
      }
    ''');

    final block = blocks.first as DependencyBlock;
    expect(block.checkType, equals('network'));
    expect(block.timeout, equals(60));
    expect(block.interval, equals(5));
    expect(block.state, equals('reachable'));
  });

  test('should fall back when type is read as check_type', () async {
    final blocks = await helper.processConfig('''
      dependency {
        host = "10.0.0.1"
        check_type = "ping"
      }
    ''');

    final block = blocks.first as DependencyBlock;
    expect(block.checkType, equals('ping'));
  });
}
