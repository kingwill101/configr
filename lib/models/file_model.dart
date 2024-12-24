import 'package:configr/extensions/list.dart';
import 'package:configr/models/action.dart';
import 'package:configr/models/command.dart';
import 'package:configr/models/template.dart';

enum ResourceType {
  file,
  directory,
}

class ResourceModel {
  final String source;
  final String destination;
  final ResourceType type;
  final bool recursive;
  final Template? template;
  final List<Action> actions;
  final List<Command> commands;
  final String sha256;
  String? status;

  ResourceModel(
      {required this.source,
      required this.destination,
      required this.actions,
      this.type = ResourceType.file,
      this.status,
      this.template,
      List<Command>? commands,
      this.recursive = false,
      String? shasum})
      : commands = commands ?? const [],
        sha256 = shasum ?? '';

  @override
  int get hashCode => Object.hash(
        source,
        template,
        status,
        destination,
        type,
        recursive,
        Object.hashAll(actions),
        Object.hashAll(commands),
      );

  @override
  String toString() {
    return 'FileModel(source: $source, destination: $destination, actions: $actions, commands: $commands, status: $status)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResourceModel &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          source == other.source &&
          destination == other.destination &&
          listEquals(actions, other.actions) &&
          template == other.template &&
          listEquals(commands, other.commands);

  factory ResourceModel.fromJson(Map<String, dynamic> json) {
    return ResourceModel(
      shasum: json['sha256'],
      status: json['status'],
      source: json['source'],
      destination: json['destination'],
      template: json['template'],
      type: ResourceType.values.byName(json['type']),
      recursive: json['recursive'],
      actions:
          (json['actions'] as List).map((a) => Action.fromJson(a)).toList(),
      commands:
          (json['commands'] as List).map((a) => Command.fromJson(a)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'template': template?.toJson(),
        'source': source,
        'type': type.name,
        'status': status,
        'recursive': recursive,
        'destination': destination,
        'actions': actions.map((a) => a.toJson()).toList(),
        'commands': commands.map((c) => c.toJson()).toList()
      };

  String toConfig({String indent = ''}) {
    StringBuffer buffer = StringBuffer();
    buffer.writeln('${indent}file {');
    buffer.writeln('$indent  source $source');
    buffer.writeln('$indent  destination $destination');
    buffer.writeln('$indent  recursive $recursive');
    buffer.writeln('$indent  status $status');
    buffer.writeln('$indent  type ${type.name}');
    buffer.writeln('$indent  sha256 $sha256');

    if (template != null) {
      buffer.write(template!.toConfig(indent: '$indent  '));
    }

    if (actions.isNotEmpty) {
      buffer.writeln('$indent  actions {');
      for (var action in actions) {
        buffer.write(action.toConfig(indent: '$indent    '));
      }
      buffer.writeln('$indent  }');
    }

    if (commands.isNotEmpty) {
      buffer.writeln('$indent  commands {');
      for (var command in commands) {
        buffer.write(command.toConfig(indent: '$indent    '));
      }
      buffer.writeln('$indent  }');
    }

    buffer.writeln('$indent}');
    return buffer.toString();
  }
}
