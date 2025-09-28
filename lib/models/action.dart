import 'package:configr/extensions/string.dart';

import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;

class Action {
  final String id;
  final String type;
  final String? backupPath;
  late String? status;
  late String? timestamp;
  String? sha256;
  List<Action> actions;
  Map<String, dynamic> properties;
  Map<String, dynamic> state;

  Action({
    String? id,
    required this.type,
    this.backupPath,
    this.status,
    this.timestamp,
    this.sha256,
    List<Action>? actions,
    Map<String, dynamic>? properties,
    Map<String, dynamic>? state,
  })  : id = id ?? _generateId(type, properties ?? {}),
        actions = actions ?? const [],
        properties = properties ?? {},
        state = state ?? {};

  static String _generateId(String type, Map<String, dynamic> properties) {
    final data = {
      'type': type,
      'properties': Map.from(properties)
        ..remove('status')
        ..remove('timestamp')
    };
    final jsonStr = json.encode(data);
    return crypto.sha256
        .convert(utf8.encode(jsonStr))
        .toString()
        .substring(0, 8);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Action &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type &&
          backupPath == other.backupPath &&
          status == other.status &&
          timestamp == other.timestamp &&
          sha256 == other.sha256;

  @override
  int get hashCode => Object.hash(
        id,
        type,
        backupPath,
        status,
        timestamp,
        sha256,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'backupPath': backupPath,
        'status': status,
        'timestamp': timestamp,
        'sha256': sha256,
        'actions': actions.map((a) => a.toJson()).toList(),
        'properties': properties,
        'state': state,
      };

  factory Action.fromJson(Map<String, dynamic> json) {
    return Action(
      id: json['id'],
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
      state: Map<String, dynamic>.from(json['state'] ?? {}),
    );
  }

  String toConfig({String indent = ''}) {
    StringBuffer buffer = StringBuffer();
    final hasNoneNull = toJson().values.any((e) => e != null);
    if (!hasNoneNull) {
      buffer.writeln('$indent$type{}');
      return buffer.toString();
    }
    buffer.writeln('$indent$type {');
    buffer.writeln('$indent  id $id');
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