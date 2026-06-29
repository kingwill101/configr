/// Serialization model for the package lockfile.
///
/// Records what packages were installed/upgraded, by which manager,
/// and to what versions. Separate from [V2LockfileData] which tracks
/// block-level application state.
class PackageLockData {
  final List<PackageLockRecord> packages;

  final int version;

  final String? configChecksum;

  const PackageLockData({
    required this.packages,
    this.version = 1,
    this.configChecksum,
  });

  factory PackageLockData.fromJson(Map<String, dynamic> json) {
    return PackageLockData(
      packages: (json['packages'] as List? ?? [])
          .map((e) => PackageLockRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      version: json['version'] as int? ?? 1,
      configChecksum: json['config_checksum'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'config_checksum': configChecksum,
    'packages': packages.map((e) => e.toJson()).toList(),
  };
}

/// A single package record in the package lockfile.
class PackageLockRecord {
  final String name;

  final String manager;

  final String? version;

  final String appliedAt;

  final String status;

  const PackageLockRecord({
    required this.name,
    required this.manager,
    this.version,
    required this.appliedAt,
    this.status = 'completed',
  });

  factory PackageLockRecord.fromJson(Map<String, dynamic> json) {
    return PackageLockRecord(
      name: json['name'] as String,
      manager: json['manager'] as String,
      version: json['version'] as String?,
      appliedAt: json['applied_at'] as String? ?? '',
      status: json['status'] as String? ?? 'completed',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'manager': manager,
    if (version != null) 'version': version,
    'applied_at': appliedAt,
    'status': status,
  };
}
