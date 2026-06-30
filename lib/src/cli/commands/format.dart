import 'package:configr/src/utils/logging.dart';
import 'base_command.dart';

class FormatCommand extends BaseCommand {
  @override
  String get name => 'format';

  @override
  String get description => 'Format configuration file';

  @override
  Future<void> executeCommand() async {
    await _executeV2();
  }

  Future<void> _executeV2() async {
    io.title('Format Configuration (v2)');

    try {
      // Read the full config AST via FormatService (preserves all structure:
      // resources, commands, packages, scripts, nested blocks, etc.)
      final config = await runtime.readConfig();
      io.section('Configuration parsed successfully');

      // Serialize through the format boundary — I3FormatWriter handles
      // proper i3-format output with correct quoting, indentation, etc.
      // Then write the formatted output back to the file in-place.
      await runtime.writeConfig(config);

      // Count top-level blocks for user feedback
      final blockCount = config.statements.length;

      io.success(
        'Formatting complete — $blockCount block(s) processed, '
        'file updated in-place.',
      );
    } catch (e) {
      io.error('Format failed: $e');
      logger.error('Format error: $e');
    }
  }
}
