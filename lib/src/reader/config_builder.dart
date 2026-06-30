import 'package:configr/src/models/action.dart';
import 'package:configr/src/models/command.dart';
import 'package:configr/src/models/config.dart';
import 'package:configr/src/models/file_model.dart';
import 'package:configr/src/models/package.dart';
import 'package:configr/src/models/template.dart';

/// Builder for constructing a [Config] domain model through the handler pipeline.
///
/// Handlers mutate this builder while processing i3config v2 AST nodes,
/// and [build] materializes the final [Config] at the end.
class ConfigBuilder {
  final List<ResourceModel> resources = [];
  final List<Command> commands = [];
  final List<Package> packages = [];
  final List<String> preApplyScripts = [];
  final List<String> postApplyScripts = [];

  Config build() {
    return Config(
      resources: List.from(resources),
      commands: List.from(commands),
      packages: List.from(packages),
      preApplyScripts: List.from(preApplyScripts),
      postApplyScripts: List.from(postApplyScripts),
    );
  }
}

/// Builder for constructing a single [ResourceModel] from block processing.
class ResourceBuilder {
  String? id;
  String? source;
  String? destination;
  String? type;
  String? status;
  String? sha256;
  Template? template;
  final List<Action> actions = [];
  final List<Command> commands = [];
  final Map<String, dynamic> extraProperties = {};

  ResourceModel build() {
    final resolvedType = type ?? ResourceType.file;
    final resolvedId = id ?? _generateId();
    return ResourceModel(
      id: resolvedId,
      source: source ?? '',
      destination: destination ?? '',
      type: resolvedType == ResourceType.file ? null : resolvedType,
      status: status,
      actions: List.from(actions),
      commands: List.from(commands),
      template: template,
      shasum: sha256,
      properties: {
        ...extraProperties,
        if (source != null) 'source': source,
        if (destination != null) 'destination': destination,
        if (type != null) 'type': type,
      },
    );
  }

  String _generateId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch & 0xFFFFFFFF;
    return 'resource_${timestamp.toRadixString(16)}';
  }
}

/// Builder for constructing a single [Action] from block processing.
class ActionBuilder {
  String type;
  String? id;
  String? status;
  String? timestamp;
  String? sha256;
  final Map<String, dynamic> properties = {};
  final List<Action> nestedActions = [];

  ActionBuilder({required this.type});

  Action build() {
    return Action(
      id: id,
      type: type,
      status: status,
      timestamp: timestamp,
      sha256: sha256,
      actions: List.from(nestedActions),
      properties: Map.from(properties),
    );
  }
}

/// Builder for constructing a single [Command] from block processing.
class CommandBuilder {
  String? name;
  String? id;
  String? command;
  final List<String> parameters = [];
  String? status;
  String? timestamp;
  String? sha256;

  Command build() {
    return Command(
      name: name ?? '',
      id: id,
      command: command,
      parameters: List.from(parameters),
      status: status,
      timestamp: timestamp,
      sha256: sha256,
    );
  }
}

/// Builder for constructing a single [Package] from block processing.
class PackageBuilder {
  String? id;
  String? name;
  String? manager;
  String? version;
  String? scope;
  String? status;
  String? timestamp;
  String? sha256;

  Package build() {
    return Package(
      id: id ?? _generateId(),
      name: name ?? '',
      manager: manager ?? '',
      version: version,
      scope: scope ?? 'global',
      status: status,
      timestamp: timestamp,
      sha256: sha256,
    );
  }

  String _generateId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch & 0xFFFFFFFF;
    return 'package_${timestamp.toRadixString(16)}';
  }
}
