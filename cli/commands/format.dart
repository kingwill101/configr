import 'package:configr/src/utils/logging.dart';
import 'package:configr/src/writer/i3_config_writer_v2.dart';
import 'base_command.dart';

class FormatCommand extends BaseCommand {
  @override
  String get name => 'format';

  @override
  String get description => 'Format configuration file';

  @override
  void executeCommand() async {
    final useV2 = configrConfig.useV2;

    if (useV2) {
      await _executeV2();
    } else {
      await _executeV1();
    }
  }

  Future<void> _executeV2() async {
    io.title('Format Configuration (v2)');

    try {
      final blocks = await runtime.parseAndCollect();
      io.section('Configuration parsed successfully');

      // Use the v2 writer for proper i3-format serialization
      final writer = I3ConfigWriterV2();
      final formatted = writer.writeBlocks(blocks);

      io.line(formatted);

      io.success('Formatting complete — ${blocks.length} blocks processed.');
    } catch (e) {
      io.error('Format failed: $e');
      logger.severe('Format error: $e');
    }
  }

  Future<void> _executeV1() async {
    io.title('Format Configuration (v1)');
    await configManager.load();
    configManager.saveConfig();
    io.success('Formatted successfully.');
  }
}
