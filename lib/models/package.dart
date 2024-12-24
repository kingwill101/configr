class Package {
  final String name;
  final String manager;
  final String? version;
  final String scope;
  late String? status;
  late String? timestamp;
  late String? sha256;

  Package({
    required this.name,
    required this.manager,
    this.version,
    required this.scope,
    this.status,
    this.timestamp,
    this.sha256,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Package &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          manager == other.manager &&
          version == other.version &&
          scope == other.scope &&
          status == other.status &&
          timestamp == other.timestamp &&
          sha256 == other.sha256;

  @override
  int get hashCode => Object.hash(
        name,
        manager,
        version,
        scope,
        status,
        timestamp,
        sha256,
      );

  @override
  String toString() {
    return 'Package(name: $name, manager: $manager, version: $version, scope: $scope, status: $status, timestamp: $timestamp, sha256: $sha256)';
  }

  factory Package.fromJson(Map<String, dynamic> json) {
    return Package(
      name: json['name'],
      manager: json['manager'],
      version: json['version'],
      scope: json['scope'],
      status: json['status'],
      timestamp: json['timestamp'],
      sha256: json['sha256'],
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'manager': manager,
        'version': version,
        'scope': scope,
        'status': status,
        'timestamp': timestamp,
        'sha256': sha256,
      };

  String toConfig({String indent = ''}) {
    StringBuffer buffer = StringBuffer();
    buffer.writeln('${indent}package {');
    buffer.writeln('$indent  name "$name"');
    buffer.writeln('$indent  manager "$manager"');
    if (version != null) buffer.writeln('$indent  version "$version"');
    buffer.writeln('$indent  scope "$scope"');
    if (status != null) buffer.writeln('$indent  status "$status"');
    if (timestamp != null) buffer.writeln('$indent  timestamp "$timestamp"');
    if (sha256 != null) buffer.writeln('$indent  sha256 "$sha256"');
    buffer.writeln('$indent}');
    return buffer.toString();
  }
}
