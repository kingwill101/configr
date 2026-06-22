import 'package:configr/src/utils/logging.dart';
import 'base_command.dart';

class DiffCommand extends BaseCommand {
  @override
  String get name => 'diff';

  @override
  String get description => 'Show configuration differences';

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
    io.title('Configuration Diff');

    try {
      final blocks = await runtime.parseAndCollect();
      io.section('Found ${blocks.length} action block(s)');
      for (final snapshot in blocks) {
        final status = snapshot.status ?? 'pending';
        final icon = switch (status) {
          'completed' => '✅',
          'failed' => '❌',
          _ => '⏳',
        };
        io.line(
          '  $icon ${snapshot.blockType}: ${snapshot.id.isEmpty ? '(unnamed)' : snapshot.id}',
        );
        if (snapshot.source.isNotEmpty) {
          io.line('     source: ${snapshot.source}');
        }
        if (snapshot.destination.isNotEmpty) {
          io.line('     destination: ${snapshot.destination}');
        }
      }
      io.success('Diff complete — ${blocks.length} blocks parsed.');
    } catch (e) {
      io.error('Diff failed: $e');
      logger.severe('Diff error: $e');
    }
  }

  Future<void> _executeV1() async {
    io.title('Configuration Diff (v1)');
    io.line('Diffing config at: ${configManager.localPath}');
    await configManager.load();
    io.warn('v1 diff: detailed comparison not yet implemented.');
  }
}
