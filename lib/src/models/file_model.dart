import 'package:configr/src/extensions/list.dart';
import 'package:configr/src/models/action.dart';
import 'package:configr/src/models/command.dart';
import 'package:configr/src/models/template.dart';
import 'package:collection/collection.dart';

class ResourceType {
  static const String file = 'file';
  static const String directory = 'directory';
}

class ResourceModel {
  final String id;
  final String source;
  final String destination;
  final String? type;
  final Template? template;
  final List<Action> actions;
  final List<Command> commands;
  final Map<String, dynamic> properties;
  String? sha256;
  String? status;

  ResourceModel(
      {required this.id,
      required this.source,
      required this.destination,
      required this.actions,
      this.type,
      this.status,
      this.template,
      List<Command>? commands,
      String? shasum,
      Map<String, dynamic>? properties})
      : commands = commands ?? const [],
        sha256 = shasum ?? '',
        properties = properties ?? {};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResourceModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          sha256 == other.sha256 &&
          status == other.status &&
          source == other.source &&
          destination == other.destination &&
          listEquals(actions, other.actions) &&
          template == other.template &&
          listEquals(commands, other.commands) &&
          const DeepCollectionEquality().equals(properties, other.properties);

  @override
  int get hashCode => Object.hash(
        id,
        sha256,
        source,
        template,
        status,
        destination,
        type,
        Object.hashAll(actions),
        Object.hashAll(commands),
        Object.hashAll(properties.entries),
      );

  factory ResourceModel.fromJson(Map<String, dynamic> json) {
    return ResourceModel(
      id: json['id'] as String,
      source: json['source'] as String,
      destination: json['destination'] as String,
      type: json['type'] as String?,
      status: json['status'] as String?,
      template:
          json['template'] != null ? Template.fromJson(json['template']) : null,
      actions: (json['actions'] as List?)
              ?.map((a) => Action.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      commands: (json['commands'] as List?)
              ?.map((c) => Command.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      shasum: json['sha256'] as String?,
      properties: Map<String, dynamic>.from(json['properties'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'source': source,
        'destination': destination,
        'type': type,
        'status': status,
        'template': template?.toJson(),
        'actions': actions.map((a) => a.toJson()).toList(),
        'commands': commands.map((c) => c.toJson()).toList(),
        'sha256': sha256,
        'properties': properties,
      };

  String toConfig({String indent = ''}) {
    StringBuffer buffer = StringBuffer();
    buffer.writeln('${indent}file {');
    buffer.writeln('$indent  id $id');
    buffer.writeln('$indent  source $source');
    buffer.writeln('$indent  destination $destination');
    buffer.writeln('$indent  status $status');
    buffer.writeln('$indent  type $type');
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
