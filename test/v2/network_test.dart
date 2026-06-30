import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should initialize with default values', () async {
    final blocks = await helper.processConfig('''
      network {
        source = "https://example.com"
        operation = "connectivity"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first;
    expect(block.blockType, equals('network'));
  });

  test('should update state with configuration', () async {
    final blocks = await helper.processConfig('''
      network {
        source = "https://example.com"
        operation = "http"
        port = 443
        timeout = 30
        method = "GET"
      }
    ''');

    final block = blocks.first;
    expect((block as dynamic).operation, equals('http'));
    expect((block as dynamic).port, equals(443));
    expect((block as dynamic).timeout, equals(30));
    expect((block as dynamic).method, equals('GET'));
  });
}
