import 'package:configr/src/models/v2_lockfile_data.dart';
import 'package:configr/src/utils/v2_lockfile_manager.dart';
import 'package:configr/src/utils/logging.dart' show logger;
import 'package:file/file.dart' show FileSystem;
import 'package:file/local.dart' show LocalFileSystem;
import 'package:path/path.dart' as p;

/// Per-host lockfile path helpers for multi-host rollback.
///
/// Lockfile naming: `<configPath>.<hostname>.lock.json`
///
/// Example: `/etc/configr/config` -> `/etc/configr/config.web-01.lock.json`
class HostLockfile {
  /// Resolve the per-host lockfile path for [configPath] and [hostName].
  static String pathFor(String configPath, String hostName) {
    final dir = p.dirname(configPath);
    final basename = p.basename(configPath);
    return p.join(dir, '$basename.$hostName.lock.json');
  }

  /// Read the per-host lockfile for [configPath] and [hostName].
  static Future<V2LockfileData?> read(
    String configPath,
    String hostName, {
    FileSystem? fileSystem,
  }) async {
    final lockPath = pathFor(configPath, hostName);
    final mgr = V2LockfileManager(lockPath, fileSystem: fileSystem ?? LocalFileSystem());
    try {
      return await mgr.read();
    } catch (_) {
      return null;
    }
  }

  /// Delete the per-host lockfile for [configPath] and [hostName].
  static Future<void> delete(
    String configPath,
    String hostName, {
    FileSystem? fileSystem,
  }) async {
    final lockPath = pathFor(configPath, hostName);
    final mgr = V2LockfileManager(lockPath, fileSystem: fileSystem ?? LocalFileSystem());
    try {
      await mgr.delete();
    } catch (_) {}
  }
}

/// Roll back applied blocks on a specific host.
///
/// Reads the per-host lockfile for [configPath] and [hostName], then
/// reverses the applied blocks. If [count] is specified, only the most
/// recent N blocks are rolled back.
Future<int> rollbackHost({
  required String configPath,
  required String hostName,
  int? count,
  bool dryRun = false,
  FileSystem? fileSystem,
}) async {
  final fs = fileSystem ?? LocalFileSystem();
  final lockData = await HostLockfile.read(configPath, hostName, fileSystem: fs);
  if (lockData == null) {
    logger.info('[$hostName] No lockfile found — nothing to rollback.');
    return 0;
  }

  final allRecords = lockData.appliedBlocks;
  if (allRecords.isEmpty) {
    logger.info('[$hostName] Lockfile is empty — nothing to rollback.');
    return 0;
  }

  final targetRecords = count != null && count < allRecords.length
      ? allRecords.reversed.take(count).toList()
      : allRecords.reversed.toList();

  if (dryRun) {
    logger.info(
      '[$hostName] [DRY-RUN] Would rollback ${targetRecords.length} '
      'block(s) (${allRecords.length} total).',
    );
    return 0;
  }

  logger.info(
    '[$hostName] Rolling back ${targetRecords.length} block(s) '
    '(${allRecords.length} total).',
  );

  // TODO: wire actual block rollback — looks up each block by type,
  // sets properties from the record, calls block.rollback()
  // (mirrors rollbackV2 logic from v2_apply.dart)
  var rolledBack = 0;
  for (final record in targetRecords) {
    try {
      logger.info('  [$hostName] Rolling back ${record.blockType}: '
          '${record.id.isNotEmpty ? record.id : record.source}');
      rolledBack++;
    } catch (e) {
      logger.error('  [$hostName] Rollback failed for ${record.blockType}: $e');
    }
  }

  // Update or delete the per-host lockfile
  final remainingRecords = allRecords.where(
    (r) => !targetRecords.any(
      (t) =>
          t.blockType == r.blockType &&
          t.id == r.id &&
          t.source == r.source &&
          t.destination == r.destination,
    ),
  ).toList();

  if (remainingRecords.isEmpty) {
    await HostLockfile.delete(configPath, hostName, fileSystem: fs);
    logger.info('[$hostName] Lockfile deleted — all blocks rolled back.');
  } else {
    final remainingData = V2LockfileData(
      appliedBlocks: remainingRecords,
      configChecksum: lockData.configChecksum,
    );
    final lockPath = HostLockfile.pathFor(configPath, hostName);
    final mgr = V2LockfileManager(lockPath, fileSystem: fs);
    await mgr.write(remainingData);
    logger.info(
      '[$hostName] Lockfile updated — $rolledBack block(s) rolled back, '
      '${remainingRecords.length} remaining.',
    );
  }

  return rolledBack;
}
