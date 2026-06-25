import 'package:configr/src/di.dart';
import 'package:configr/src/models/v2_lockfile_data.dart';
import 'package:configr/src/utils/file_service.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:configr/src/utils/v2_lockfile_manager.dart';
import 'package:file/file.dart' show FileSystem;

/// The result of a drift check for a single applied block.
class DriftResult {
  final AppliedBlockRecord record;
  final DriftState state;
  final String? currentChecksum;

  const DriftResult({
    required this.record,
    required this.state,
    this.currentChecksum,
  });
}

/// Whether a previously-applied file has drifted from its recorded state.
enum DriftState {
  /// File matches the recorded checksum — no drift.
  synced,

  /// File content has changed — drifted.
  drifted,

  /// File no longer exists on disk.
  missing,

  /// No checksum was recorded for this block — can't detect drift.
  unknown,
}

/// Reads the lockfile and compares the recorded checksums against current
/// file states to detect drift.
///
/// Only checks blocks that have a non-empty [AppliedBlockRecord.destination]
/// (the output file path). Blocks without a destination or without a recorded
/// [AppliedBlockRecord.sha256] are reported as [DriftState.unknown].
Future<List<DriftResult>> checkDrift(String configPath) async {
  final lockMgr = V2LockfileManager(
    V2LockfileManager.lockPathFor(configPath),
    fileSystem: di<FileSystem>(),
  );

  V2LockfileData lockData;
  try {
    lockData = await lockMgr.read();
  } catch (e) {
    logger.info('No lockfile found at ${lockMgr.lockfilePath} — skipping drift check.');
    return [];
  }

  if (lockData.appliedBlocks.isEmpty) return [];

  final fileService = di<FileService>();
  final results = <DriftResult>[];

  for (final record in lockData.appliedBlocks) {
    if (record.destination.isEmpty) {
      results.add(DriftResult(record: record, state: DriftState.unknown));
      continue;
    }

    if (record.sha256 == null || record.sha256!.isEmpty) {
      results.add(DriftResult(record: record, state: DriftState.unknown));
      continue;
    }

    try {
      if (!await fileService.fileExists(record.destination)) {
        results.add(DriftResult(record: record, state: DriftState.missing));
        continue;
      }

      final current = await fileService.computeFileHash(record.destination);
      if (current == record.sha256) {
        results.add(DriftResult(
          record: record,
          state: DriftState.synced,
          currentChecksum: current,
        ));
      } else {
        results.add(DriftResult(
          record: record,
          state: DriftState.drifted,
          currentChecksum: current,
        ));
      }
    } catch (e) {
      logger.warning('Drift check failed for ${record.blockType}: $e');
      results.add(DriftResult(record: record, state: DriftState.unknown));
    }
  }

  return results;
}
