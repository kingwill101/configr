import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should initialize download with default values', () async {
    final blocks = await helper.processConfig('''
      download {
        source = "https://example.com/file.txt"
        destination = "/dest/file.txt"
      }
    ''');

    expect(blocks, hasLength(1));
    expect(blocks.first.blockType, equals('download'));
    expect(blocks.first.source, equals('https://example.com/file.txt'));
    expect(blocks.first.destination, equals('/dest/file.txt'));
  });

  test('should parse overwrite option', () async {
    final blocks = await helper.processConfig('''
      download {
        source = "https://example.com/bytes/512"
        destination = "/dest/file.bin"
        overwrite = true
      }
    ''');

    expect(blocks, hasLength(1));
    expect(blocks.first.blockType, equals('download'));
  });
}
