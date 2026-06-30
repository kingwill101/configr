import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should initialize with default values', () async {
    final blocks = await helper.processConfig('''
      execute {
        command = "echo test"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first;
    expect(block.blockType, equals('execute'));
  });

  test('should parse command and timeout from config', () async {
    final blocks = await helper.processConfig('''
      execute {
        command = "echo Hello World"
        timeout = 5000
        working_directory = "/tmp"
      }
    ''');

    final block = blocks.first;
    expect(block.blockType, equals('execute'));
    expect((block as dynamic).timeoutSeconds, equals(5000));
  });
}
