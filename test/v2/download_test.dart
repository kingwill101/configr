import 'package:configr/src/blocks/download_block.dart';
import 'package:configr/src/utils/network_service.dart';
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

  test('should parse transfer mode', () async {
    final blocks = await helper.processConfig('''
      download {
        source = "https://example.com/bytes/512"
        destination = "/dest/file.bin"
        transfer_mode = "controller"
      }
    ''');

    final block = blocks.single as DownloadBlock;
    expect(block.transferMode, equals(DownloadTransferMode.controller));
  });
}
