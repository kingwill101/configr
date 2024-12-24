import 'package:configr/extensions/list.dart';

class Command {
  final String name;
  final String? command;
  final List<String> parameters;
  late String? status;
  late String? timestamp;
  final String? sha256;

  Command({
    required this.name,
    this.command,
    List<String>? parameters = const [],
    this.status,
    this.timestamp,
    this.sha256,
  }) : parameters = parameters ?? const [];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Command &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          command == other.command &&
          listEquals(parameters, other.parameters) &&
          status == other.status &&
          timestamp == other.timestamp &&
          sha256 == other.sha256;

  @override
  int get hashCode => Object.hash(
        name,
        command,
        Object.hashAll(parameters),
        status,
        timestamp,
        sha256,
      );

  @override
  String toString() {
    return 'Command(name: $name, command: $command, parameters: $parameters, status: $status, timestamp: $timestamp, sha256: $sha256)';
  }

  factory Command.fromJson(Map<String, dynamic> json) {
    return Command(
      name: json['name'],
      command: json['command'],
      parameters: List<String>.from(json['parameters'] ?? []),
      status: json['status'],
      timestamp: json['timestamp'],
      sha256: json['sha256'],
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'command': command,
        'parameters': parameters,
        'status': status,
        'timestamp': timestamp,
        'sha256': sha256,
      };

  String toConfig({String indent = ''}) {
    StringBuffer buffer = StringBuffer();
    buffer.writeln('$indent$name {');
    if (command != null) buffer.writeln('$indent  command "$command"');
    if (parameters.isNotEmpty) {
      buffer.writeln('$indent  parameters "${parameters.join(' ')}"');
    }
    if (status != null) buffer.writeln('$indent  status "$status"');
    if (timestamp != null) buffer.writeln('$indent  timestamp "$timestamp"');
    if (sha256 != null) buffer.writeln('$indent  sha256 "$sha256"');
    buffer.writeln('$indent}');
    return buffer.toString();
  }
}
