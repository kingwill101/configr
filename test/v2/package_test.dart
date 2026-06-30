import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should initialize with default values', () async {
    final blocks = await helper.processConfig('''
      apt {
        source = "curl"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first;
    expect(block.blockType, equals('apt'));
    expect((block as dynamic).packageManager, equals('apt'));
    expect((block as dynamic).operation, equals('install'));
    expect((block as dynamic).force, isFalse);
    expect((block as dynamic).skipIfInstalled, isTrue);
  });

  test('should load configuration from properties', () async {
    final blocks = await helper.processConfig('''
      apt {
        source = "vim git curl"
        operation = "install"
        force = true
        skip_if_installed = false
      }
    ''');

    final block = blocks.first;
    expect((block as dynamic).packageManager, equals('apt'));
    expect((block as dynamic).operation, equals('install'));
    expect((block as dynamic).force, isTrue);
    expect((block as dynamic).skipIfInstalled, isFalse);
  });
}
