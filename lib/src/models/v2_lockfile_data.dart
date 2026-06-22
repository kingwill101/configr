/// Serialization model for the v2 lockfile.
///
/// Records what blocks were applied, in what order, and with what
/// parameters so that [rollbackV2] can undo only previously-applied
/// blocks without having to re-parse the current config.
class V2LockfileData {
  /// The list of applied block records, in application order.
  final List<AppliedBlockRecord> appliedBlocks;

  /// Version stamp for forward-compatibility.
  final int version;

  /// SHA-256 of the config file at apply time (optional — for dirty detection).
  final String? configChecksum;

  const V2LockfileData({
    required this.appliedBlocks,
    this.version = 2,
    this.configChecksum,
  });

  factory V2LockfileData.fromJson(Map<String, dynamic> json) {
    return V2LockfileData(
      appliedBlocks: (json['applied_blocks'] as List? ?? [])
          .map((e) => AppliedBlockRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      version: json['version'] as int? ?? 2,
      configChecksum: json['config_checksum'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'config_checksum': configChecksum,
    'applied_blocks': appliedBlocks.map((e) => e.toJson()).toList(),
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

  const AppliedBlockRecord({
    required this.blockType,
    required this.id,
    required this.source,
    required this.destination,
    required this.appliedAt,
    this.status = 'completed',
    this.sha256,
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
  };
}
