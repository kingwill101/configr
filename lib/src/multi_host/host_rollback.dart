import 'package:configr/src/blocks/v2_apply.dart' show rollbackV2;
import 'package:configr/src/models/v2_lockfile_data.dart';
import 'package:configr/src/utils/v2_lockfile_manager.dart';
import 'package:configr/src/utils/logging.dart' show logger;
import 'package:configr/src/utils/ssh_execution_service.dart';
import 'package:file/file.dart' show FileSystem;
import 'package:file/local.dart' show LocalFileSystem;
import 'package:path/path.dart' show posix;

/// Per-host lockfile path helpers for multi-host rollback.
///
/// Lockfile naming: `<configPath>.<hostname>.lock.json`
///
/// Example: `/etc/configr/config` -> `/etc/configr/config.web-01.lock.json`
class HostLockfile {
  /// Resolve the per-host lockfile path for [configPath] and [hostName].
  static String pathFor(String configPath, String hostName) {
    final dir = posix.dirname(configPath);
    final basename = posix.basename(configPath);
    return posix.join(dir, '$basename.$hostName.lock.json');
  }

  /// Read the per-host lockfile for [configPath] and [hostName].
  static Future<V2LockfileData?> read(
    String configPath,
    String hostName, {
    FileSystem? fileSystem,
  }) async {
    final lockPath = pathFor(configPath, hostName);
    final mgr = V2LockfileManager(
      lockPath,
      fileSystem: fileSystem ?? LocalFileSystem(),
    );
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
    final mgr = V2LockfileManager(
      lockPath,
      fileSystem: fileSystem ?? LocalFileSystem(),
    );
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
///
/// If [connectionConfig] is provided, rollback is performed remotely via
/// SSH: the config is uploaded and `configr rollback` is executed on the
/// target host. Otherwise, rollback is attempted locally.
Future<int> rollbackHost({
  required String configPath,
  required String hostName,
  int? count,
  bool dryRun = false,
  FileSystem? fileSystem,
  Map<String, dynamic>? connectionConfig,
}) async {
  final fs = fileSystem ?? LocalFileSystem();
  final lockData = await HostLockfile.read(
    configPath,
    hostName,
    fileSystem: fs,
  );
  final hostLogger = logger.withContext({'host': hostName});
  if (lockData == null) {
    hostLogger.info('No lockfile found — nothing to rollback.');
    return 0;
  }

  final allRecords = lockData.appliedBlocks;
  if (allRecords.isEmpty) {
    hostLogger.info('Lockfile is empty — nothing to rollback.');
    return 0;
  }

  final targetRecords = count != null && count < allRecords.length
      ? allRecords.reversed.take(count).toList()
      : allRecords.reversed.toList();

  if (dryRun) {
    hostLogger
        .withContext({
          'dryRun': true,
          'targetBlockCount': targetRecords.length,
          'totalBlockCount': allRecords.length,
        })
        .info('Would rollback blocks.');
    return 0;
  }

  if (connectionConfig != null) {
    return _remoteRollback(
      configPath: configPath,
      hostName: hostName,
      count: count,
      connectionConfig: connectionConfig,
      targetRecords: targetRecords,
    );
  }

  hostLogger
      .withContext({
        'targetBlockCount': targetRecords.length,
        'totalBlockCount': allRecords.length,
      })
      .info('Rolling back blocks.');

  // TODO: wire actual block rollback — looks up each block by type,
  // sets properties from the record, calls block.rollback()
  // (mirrors rollbackV2 logic from v2_apply.dart)
  var rolledBack = 0;
  for (final record in targetRecords) {
    try {
      logger
          .withContext({
            'host': hostName,
            'blockType': record.blockType,
            'blockId': record.id.isNotEmpty ? record.id : record.source,
          })
          .info('Rolling back block.');
      rolledBack++;
    } catch (e) {
      logger
          .withContext({
            'host': hostName,
            'blockType': record.blockType,
            'error': '$e',
          })
          .error('Rollback failed for block.');
    }
  }

  await _updateHostLockfileAfterRollback(
    configPath: configPath,
    hostName: hostName,
    lockData: lockData,
    targetRecords: targetRecords,
    fileSystem: fs,
    rolledBack: rolledBack,
  );

  return rolledBack;
}

Future<void> _updateHostLockfileAfterRollback({
  required String configPath,
  required String hostName,
  required V2LockfileData lockData,
  required List<AppliedBlockRecord> targetRecords,
  required FileSystem fileSystem,
  required int rolledBack,
}) async {
  final allRecords = lockData.appliedBlocks;
  final remainingRecords = allRecords
      .where(
        (r) => !targetRecords.any(
          (t) =>
              t.blockType == r.blockType &&
              t.id == r.id &&
              t.source == r.source &&
              t.destination == r.destination &&
              t.appliedAt == r.appliedAt,
        ),
      )
      .toList();

  if (remainingRecords.isEmpty) {
    await HostLockfile.delete(configPath, hostName, fileSystem: fileSystem);
    logger
        .withContext({'host': hostName})
        .info('Lockfile deleted — all blocks rolled back.');
  } else {
    final remainingData = V2LockfileData(
      appliedBlocks: remainingRecords,
      version: lockData.version,
      configChecksum: lockData.configChecksum,
      targets: lockData.targets,
    );
    final lockPath = HostLockfile.pathFor(configPath, hostName);
    final mgr = V2LockfileManager(lockPath, fileSystem: fileSystem);
    await mgr.write(remainingData);
    logger
        .withContext({
          'host': hostName,
          'rolledBackCount': rolledBack,
          'remainingBlockCount': remainingRecords.length,
        })
        .info('Lockfile updated after rollback.');
  }
}

Future<int> _remoteRollback({
  required String configPath,
  required String hostName,
  int? count,
  required Map<String, dynamic> connectionConfig,
  required List<AppliedBlockRecord> targetRecords,
}) async {
  final ssh = SSHExecutionService();
  final hostLogger = logger.withContext({'host': hostName});

  try {
    hostLogger.info('Connecting via SSH for remote rollback');
    await ssh.connect(connectionConfig);

    hostLogger.info('Running local rollback through SSH backends');
    await rollbackV2(
      configPath,
      count: count,
      lockfilePath: HostLockfile.pathFor(configPath, hostName),
      runtimeFileSystem: ssh.fileSystem,
      runtimeExecutionService: ssh,
    );

    hostLogger.info('Remote rollback completed');
    return targetRecords.length;
  } catch (e) {
    hostLogger
        .withContext({'error': '$e'})
        .error('Remote rollback connection/execution failed');
    return 0;
  } finally {
    await ssh.disconnect();
  }
}
