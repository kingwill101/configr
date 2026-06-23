import 'package:configr/src/utils/logging.dart';
import 'base_command.dart';

class StatusCommand extends BaseCommand {
  @override
  String get name => 'status';

  @override
  String get description => 'Show configuration status';

  @override
  Future<void> executeCommand() async {
    await _executeV2();
  }

  Future<void> _executeV2() async {
    io.title('Configuration Status (v2)');

    try {
      final blocks = await runtime.parseAndCollect();

      if (blocks.isEmpty) {
        io.warn('No action blocks found in configuration.');
        return;
      }

      io.section('${blocks.length} action block(s) configured:');

      // Group blocks by type for summary
      final byType = <String, List<ActionBlockSummary>>{};
      for (final snapshot in blocks) {
        byType
            .putIfAbsent(snapshot.blockType, () => [])
            .add(
              ActionBlockSummary(
                id: snapshot.id.isEmpty ? '(unnamed)' : snapshot.id,
                source: snapshot.source,
                destination: snapshot.destination,
                status: snapshot.status,
              ),
            );
      }

      for (final entry in byType.entries) {
        io.line('  ${entry.key}: ${entry.value.length} block(s)');
        for (final summary in entry.value) {
          final statusIcon = switch (summary.status) {
            'completed' => '✅',
            'failed' => '❌',
            _ => '⏳',
          };
          io.line('    $statusIcon ${summary.id}');
          if (summary.source.isNotEmpty) {
            io.line('         source: ${summary.source}');
          }
          if (summary.destination.isNotEmpty) {
            io.line('         destination: ${summary.destination}');
          }
        }
      }

      io.success('Status check complete — ${blocks.length} blocks found.');
    } catch (e) {
      io.error('Status check failed: $e');
      logger.severe('Status error: $e');
    }
  }
}

/// Lightweight summary of a parsed action block for status display.
class ActionBlockSummary {
  final String id;
  final String source;
  final String destination;
  final String? status;

  const ActionBlockSummary({
    required this.id,
    required this.source,
    required this.destination,
    this.status,
  });
}
