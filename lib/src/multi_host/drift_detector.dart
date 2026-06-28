import 'package:configr/src/models/v2_lockfile_data.dart';
import 'package:configr/src/multi_host/host_rollback.dart' show HostLockfile;
import 'package:configr/src/utils/logging.dart' show logger;
import 'package:file/file.dart' show FileSystem;

/// Result of a drift check for a single host.
class DriftResult {
  final String hostName;
  final bool hasDrift;
  final String? message;
  final V2LockfileData? lockData;

  const DriftResult({
    required this.hostName,
    required this.hasDrift,
    this.message,
    this.lockData,
  });
}

/// Detects configuration drift across hosts by comparing per-host lockfiles.
///
/// Drift occurs when hosts have different applied block sets, different
/// checksums, or missing lockfiles (never applied).
class DriftDetector {
  /// Check a single host for drift against the expected state.
  ///
  /// Returns a [DriftResult] indicating whether the host has drifted
  /// and the details.
  Future<DriftResult> checkHost({
    required String configPath,
    required String hostName,
    required List<AppliedBlockRecord> expectedBlocks,
    String? expectedChecksum,
    FileSystem? fileSystem,
  }) async {
    final lockData = await HostLockfile.read(configPath, hostName, fileSystem: fileSystem);

    if (lockData == null) {
      return DriftResult(
        hostName: hostName,
        hasDrift: true,
        message: 'No lockfile found — host may not have been configured.',
      );
    }

    // Check config checksum mismatch
    if (expectedChecksum != null &&
        lockData.configChecksum != null &&
        lockData.configChecksum != expectedChecksum) {
      return DriftResult(
        hostName: hostName,
        hasDrift: true,
        message: 'Config checksum mismatch '
            '(applied: ${lockData.configChecksum}, expected: $expectedChecksum).',
        lockData: lockData,
      );
    }

    // Check block count difference
    if (lockData.appliedBlocks.length != expectedBlocks.length) {
      return DriftResult(
        hostName: hostName,
        hasDrift: true,
        message: 'Block count mismatch '
            '(applied: ${lockData.appliedBlocks.length}, expected: ${expectedBlocks.length}).',
        lockData: lockData,
      );
    }

    // Check block-level drift
    for (int i = 0; i < expectedBlocks.length; i++) {
      final expected = expectedBlocks[i];
      final actual = i < lockData.appliedBlocks.length
          ? lockData.appliedBlocks[i]
          : null;

      if (actual == null) {
        return DriftResult(
          hostName: hostName,
          hasDrift: true,
          message: 'Missing block at index $i: ${expected.blockType} '
              '(${expected.source}).',
          lockData: lockData,
        );
      }

      if (actual.blockType != expected.blockType ||
          actual.source != expected.source ||
          actual.sha256 != expected.sha256) {
        return DriftResult(
          hostName: hostName,
          hasDrift: true,
          message: 'Block mismatch at index $i: '
              'expected ${expected.blockType}(${expected.source}), '
              'found ${actual.blockType}(${actual.source}).',
          lockData: lockData,
        );
      }
    }

    return DriftResult(
      hostName: hostName,
      hasDrift: false,
      message: 'No drift detected.',
      lockData: lockData,
    );
  }

  /// Check multiple hosts for drift.
  ///
  /// [hostNames] is the list of hosts to check.
  /// [expectedBlocks] is the reference block list (e.g. from a baseline host).
  /// Returns a list of [DriftResult] for hosts that have drifted.
  Future<List<DriftResult>> checkHosts({
    required String configPath,
    required List<String> hostNames,
    required List<AppliedBlockRecord> expectedBlocks,
    String? expectedChecksum,
    FileSystem? fileSystem,
  }) async {
    final results = <DriftResult>[];

    for (final hostName in hostNames) {
      final result = await checkHost(
        configPath: configPath,
        hostName: hostName,
        expectedBlocks: expectedBlocks,
        expectedChecksum: expectedChecksum,
        fileSystem: fileSystem,
      );

      if (result.hasDrift) {
        results.add(result);
      } else {
        logger.info('[$hostName] No drift detected.');
      }
    }

    return results;
  }

  /// Find hosts that are missing lockfiles entirely.
  Future<List<String>> findUnconfiguredHosts({
    required String configPath,
    required List<String> hostNames,
    FileSystem? fileSystem,
  }) async {
    final unconfigured = <String>[];

    for (final hostName in hostNames) {
      final lockData = await HostLockfile.read(configPath, hostName, fileSystem: fileSystem);
      if (lockData == null) {
        unconfigured.add(hostName);
      }
    }

    return unconfigured;
  }
}
