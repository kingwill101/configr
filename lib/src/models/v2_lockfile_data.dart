/// Serialization model for the v2 lockfile.
///
/// Records what blocks were applied, in what order, and with what
/// parameters so that [rollbackV2] can undo only previously-applied
/// blocks without having to re-parse the current config.
///
/// When running in multi-host mode, [targets] captures the status of
/// each target host that was included in a consolidated deploy.
class V2LockfileData {
  /// The list of applied block records, in application order.
  final List<AppliedBlockRecord> appliedBlocks;

  /// Version stamp for forward-compatibility.
  final int version;

  /// SHA-256 of the config file at apply time (optional — for dirty detection).
  final String? configChecksum;

  /// Per-target-host execution status from consolidated multi-host runs.
  ///
  /// Maps target host names to their [TargetLockEntry] so a consolidated
  /// lockfile can be used to inspect or rollback per-host status.
  final Map<String, TargetLockEntry>? targets;

  const V2LockfileData({
    required this.appliedBlocks,
    this.version = 2,
    this.configChecksum,
    this.targets,
  });

  factory V2LockfileData.fromJson(Map<String, dynamic> json) {
    return V2LockfileData(
      appliedBlocks: (json['applied_blocks'] as List? ?? [])
          .map((e) => AppliedBlockRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      version: json['version'] as int? ?? 2,
      configChecksum: json['config_checksum'] as String?,
      targets: (json['targets'] as Map<String, dynamic>?)?.map(
        (k, v) =>
            MapEntry(k, TargetLockEntry.fromJson(v as Map<String, dynamic>)),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'config_checksum': configChecksum,
    'applied_blocks': appliedBlocks.map((e) => e.toJson()).toList(),
    if (targets != null && targets!.isNotEmpty)
      'targets': targets!.map((k, v) => MapEntry(k, v.toJson())),
  };
}

/// A single applied block record in the lockfile.
class AppliedBlockRecord {
  /// The i3config block type keyword (e.g. `'copy'`, `'file'`, `'symlink'`).
  final String blockType;

  /// The block's `id` property (may be empty).
  final String id;

  /// The `source` value at apply time.
  final String source;

  /// The `destination` value at apply time.
  final String destination;

  /// ISO-8601 timestamp of when the block was applied.
  final String appliedAt;

  /// Status after execution.
  final String status; // 'completed' | 'failed'

  /// Optional SHA-256 of the source file at apply time (for drift detection).
  final String? sha256;

  /// Optional block-specific metadata (e.g. installed package versions).
  final Map<String, dynamic>? metadata;

  const AppliedBlockRecord({
    required this.blockType,
    required this.id,
    required this.source,
    required this.destination,
    required this.appliedAt,
    this.status = 'completed',
    this.sha256,
    this.metadata,
  });

  factory AppliedBlockRecord.fromJson(Map<String, dynamic> json) {
    return AppliedBlockRecord(
      blockType: json['block_type'] as String,
      id: json['id'] as String? ?? '',
      source: json['source'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      appliedAt: json['applied_at'] as String? ?? '',
      status: json['status'] as String? ?? 'completed',
      sha256: json['sha256'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'block_type': blockType,
    'id': id,
    'source': source,
    'destination': destination,
    'applied_at': appliedAt,
    'status': status,
    if (sha256 != null) 'sha256': sha256,
    if (metadata != null) 'metadata': metadata,
  };
}

/// Per-target execution status in a consolidated multi-host lockfile.
///
/// Records the SSH host, execution strategy, and final outcome so the
/// consolidated lockfile can drive targeted rollbacks or status queries.
class TargetLockEntry {
  /// The target host name (e.g. `'web-01'`, `'db-01'`).
  final String hostName;

  /// Execution strategy used for this target (`'linear'`, `'boot'`, `'rolling'`).
  final String strategy;

  /// Execution status (`'succeeded'`, `'failed'`, `'skipped'`).
  final String status;

  /// ISO-8601 timestamp of when the target was applied.
  final String appliedAt;

  /// Optional error message if the target failed.
  final String? errorMessage;

  const TargetLockEntry({
    required this.hostName,
    required this.strategy,
    required this.status,
    required this.appliedAt,
    this.errorMessage,
  });

  factory TargetLockEntry.fromJson(Map<String, dynamic> json) {
    return TargetLockEntry(
      hostName: json['host_name'] as String,
      strategy: json['strategy'] as String? ?? 'linear',
      status: json['status'] as String? ?? 'succeeded',
      appliedAt: json['applied_at'] as String? ?? '',
      errorMessage: json['error_message'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'host_name': hostName,
    'strategy': strategy,
    'status': status,
    'applied_at': appliedAt,
    if (errorMessage != null) 'error_message': errorMessage,
  };
}
