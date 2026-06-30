import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should echo message with default settings', () async {
    final blocks = await helper.runConfig('''
      echo {
        message = "Hello World"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first;
    expect(block.blockType, equals('echo'));
    // Properties from context variables
    expect((await _getEchoProps(block)).message, equals('Hello World'));
  });

  test('should echo message with custom level', () async {
    final blocks = await helper.runConfig('''
      echo {
        message = "Warning Message"
        level = "warning"
      }
    ''');

    final block = blocks.first;
    final props = await _getEchoProps(block);
    expect(props.message, equals('Warning Message'));
    expect(props.level, equals('warning'));
  });
}

/// Helper to read echo block properties after processing
class _EchoProps {
  final String message;
  final bool color;
  final bool verbose;
  final String level;
  _EchoProps({
    required this.message,
    required this.color,
    required this.verbose,
    required this.level,
  });
}

Future<_EchoProps> _getEchoProps(dynamic block) async {
  // Access via reflection-like approach on the block's class
  // The block was executed, properties were set during afterChildrenProcessed
  return _EchoProps(
    message: block.message ?? '',
    color: block.color ?? true,
    verbose: block.verbose ?? false,
    level: block.level ?? 'info',
  );
}
