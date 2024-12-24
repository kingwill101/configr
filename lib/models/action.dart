import 'package:configr/extensions/string.dart';

class Action {
  final String type;
  final String? backupPath;
  late String? status;
  late String? timestamp;
  String? sha256;
  List<Action> actions;
  Map<String, dynamic> properties;

  Action({
    required this.type,
    this.backupPath,
    this.status,
    this.timestamp,
    this.sha256,
    List<Action>? actions,
    Map<String, dynamic>? properties,
  })  : actions = actions ?? const [],
        properties = properties ?? {};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Action &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          backupPath == other.backupPath &&
          status == other.status &&
          timestamp == other.timestamp &&
          sha256 == other.sha256;

  @override
  int get hashCode => Object.hash(
        type,
        backupPath,
        status,
        timestamp,
        sha256,
      );

  @override
  String toString() {
    return 'Action(type: $type, backupPath: $backupPath, status: $status, timestamp: $timestamp, sha256: $sha256)';
  }

  factory Action.fromJson(Map<String, dynamic> json) {
    return Action(
      type: json['type'],
      backupPath: json['backupPath'],
      status: json['status'],
      timestamp: json['timestamp'],
      sha256: json['sha256'],
      actions: List<Action>.from(
          json['actions']?.map((x) => Action.fromJson(x)) ?? []),
      properties:
          Map<String, dynamic>.from(json['properties'] ?? {}).map((key, value) {
        if (value is String) {
          return MapEntry(key, value.unquote().unescape());
        }
        return MapEntry(key, value);
      }),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'backupPath': backupPath,
        'status': status,
        'timestamp': timestamp,
        'sha256': sha256,
        'actions': actions.map((a) => a.toJson()).toList(),
        'properties': properties,
      };

  String toConfig({String indent = ''}) {
    StringBuffer buffer = StringBuffer();
    final hasNoneNull = toJson().values.any((e) => e != null);
    if (!hasNoneNull) {
      buffer.writeln('$indent$type{}');
      return buffer.toString();
    }
    buffer.writeln('$indent$type {');
    if (backupPath != null) buffer.writeln('$indent  backupPath $backupPath');
    if (status != null) buffer.writeln('$indent  status $status');
    if (timestamp != null) buffer.writeln('$indent  timestamp $timestamp');
    if (sha256 != null) buffer.writeln('$indent  sha256 $sha256');
    if (properties.isNotEmpty) {
      for (var entry in properties.entries) {
        buffer.writeln('$indent    ${entry.key} ${entry.value}');
      }
    }

    if (actions.isNotEmpty) {
      String actionsString = '';
      for (var action in actions) {
        actionsString += action.toConfig(indent: '$indent    ');
      }
      buffer.write(actionsString);
    }
    buffer.writeln('$indent}');
    return buffer.toString();
  }
}
