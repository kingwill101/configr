import 'package:configr/src/di.dart';
import 'package:configr/src/utils/drift_checker.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:configr/src/utils/v2_lockfile_manager.dart';
import 'base_command.dart';
import 'package:file/file.dart' show FileSystem;

class StatusCommand extends BaseCommand {
  @override
  String get name => 'status';

  @override
  String get description => 'Show configuration status with drift detection';

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

      // Drift detection
      final configPath = configrConfig.configPath;
      if (configPath != null) {
        final driftResults = await _checkDriftWithDi(configPath);
        _printDriftResults(driftResults);
      }

      io.success('Status check complete — ${blocks.length} blocks found.');
    } catch (e) {
      io.error('Status check failed: $e');
      logger.severe('Status error: $e');
    }
  }

  Future<List<DriftResult>> _checkDriftWithDi(String configPath) async {
    final lockMgr = V2LockfileManager(
      V2LockfileManager.lockPathFor(configPath),
      fileSystem: di<FileSystem>(),
    );
    try {
      await lockMgr.read();
    } catch (_) {
      return [];
    }
    return checkDrift(configPath);
  }

  void _printDriftResults(List<DriftResult> results) {
    if (results.isEmpty) return;

    final drifted = results.where((r) => r.state == DriftState.drifted).toList();
    final missing = results.where((r) => r.state == DriftState.missing).toList();
    final synced = results.where((r) => r.state == DriftState.synced).toList();
    final unknown = results.where((r) => r.state == DriftState.unknown).toList();

    io.section('Drift Detection (${results.length} tracked files):');
    io.line('  ✅ ${synced.length} synced');
    io.line('  ❌ ${drifted.length} drifted');
    io.line('  💀 ${missing.length} missing');
    io.line('  ❓ ${unknown.length} unknown (no checksum recorded)');

    for (final r in drifted) {
      io.warn(
        '    ${r.record.blockType} "${r.record.id}" — '
        '${r.record.destination} has changed since apply',
      );
    }
    for (final r in missing) {
      io.warn(
        '    ${r.record.blockType} "${r.record.id}" — '
        '${r.record.destination} no longer exists',
      );
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
