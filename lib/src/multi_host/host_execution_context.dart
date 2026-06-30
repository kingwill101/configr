import 'package:configr/src/multi_host/host.dart' show Host;
import 'package:configr/src/models/v2_lockfile_data.dart'
    show AppliedBlockRecord;
import 'package:configr/src/utils/event_bus.dart' show EventBus;

/// Execution context for applying configuration on a single host.
///
/// Carries the host reference, remote config path, event bus, and result
/// tracking for a single host within a multi-host operation.
class HostExecutionContext {
  /// The target host being configured.
  final Host host;

  /// Absolute path where the config file is placed on the remote host.
  final String remoteConfigPath;

  /// Event bus for emitting host-level events.
  final EventBus eventBus;

  /// Whether this is a dry-run (no actual changes).
  final bool dryRun;

  /// Whether to stop at the first error on this host.
  final bool failFast;

  /// Whether the host execution succeeded.
  bool succeeded;

  /// Error message if the host execution failed.
  String? errorMessage;

  /// Applied block records captured while executing this host.
  final List<AppliedBlockRecord> appliedBlocks;

  HostExecutionContext({
    required this.host,
    required this.remoteConfigPath,
    required this.eventBus,
    this.dryRun = false,
    this.failFast = false,
    this.succeeded = true,
    this.errorMessage,
    List<AppliedBlockRecord>? appliedBlocks,
  }) : appliedBlocks = appliedBlocks ?? <AppliedBlockRecord>[];

  @override
  String toString() =>
      'HostExecutionContext(host: ${host.name}, remoteConfigPath: $remoteConfigPath, '
      'succeeded: $succeeded, dryRun: $dryRun, failFast: $failFast)';
}
