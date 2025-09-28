import 'package:collection/collection.dart';
import 'package:configr/exceptions.dart';
import 'package:configr/extensions/map.dart';
import 'package:configr/extensions/string.dart';
import 'package:configr/models/action.dart';
import 'package:configr/models/command.dart';
import 'package:configr/models/config.dart';
import 'package:configr/models/file_model.dart';
import 'package:configr/models/package.dart';
import 'package:configr/models/template.dart';
import 'package:configr/utils/fs.dart' as fs;
import 'package:i3config/i3config.dart' as i3config;
import 'package:path/path.dart';

class ResourceRegistry {
  final Map<String, int> _resourceCounts = {};

  String generateId(String type, [String? module, String? name]) {
    if (module != null && name != null && name.isNotEmpty) {
      return '$module.$name';
    }

    final count = (_resourceCounts[type] ?? 0) + 1;
    _resourceCounts[type] = count;
    return '${type}_$count';
  }
}

extension SectionExtension on i3config.Section {
  String get modId {
    if (properties.containsKey('name')) {
      return "$module.${properties['name']!}";
    }
    if (moduleName.isEmpty) {
      return registry.generateId(module);
    }
    return "$module.$moduleName";
  }
}

Action readAction(i3config.Section actionSection,
    {Map<String, dynamic>? propertyOverrides, String? resourceId, int? index}) {
  final actions = actionSection.children.whereType<i3config.Section>();

  final properties = {
    ...actionSection.properties,
    ...propertyOverrides ?? {},
    'status': actionSection.properties['status'],
    'timestamp': actionSection.properties['timestamp'],
    'sha256': actionSection.properties['sha256'],
  };

  return Action(
      id: properties['id'] ?? actionSection.modId,
      type: actionSection.module,
      status: properties['status'],
      timestamp: properties['timestamp'],
      sha256: properties['sha256'],
      properties: {...properties, ...propertyOverrides ?? {}},
      actions: actions
          .map((a) => readAction(a,
              propertyOverrides: propertyOverrides,
              resourceId: resourceId,
              index: index))
          .toList());
}

Command readCommand(i3config.Section commandSection) {
  final args = commandSection.properties['parameters'] ?? [];

  List<String> params = [];
  if (args is String) {
    params = args.split(' ');
  }

  return Command(
    id: commandSection.modId,
    name: commandSection.moduleName,
    command: commandSection.properties['command'],
    parameters: params,
    status: commandSection.properties['status'],
    timestamp: commandSection.properties['timestamp'],
    sha256: commandSection.properties['sha256'],
  );
}

ResourceModel readresourceModel(i3config.Section resourceSection,
    {Map<String, dynamic>? propertyOverrides, String? id}) {
  final actionsSection = resourceSection.children
      .whereType<i3config.Section>()
      .where((element) => element.name == 'actions')
      .firstOrNull;
  List<Action> actions = [];

  final resourceId =
      id ?? actionsSection?.modId ?? registry.generateId('resource');

  if (actionsSection != null) {
    actions = actionsSection.children
        .whereType<i3config.Section>()
        .mapIndexed((i, e) => readAction(e, resourceId: resourceId, index: i))
        .toList();
  }

  final subCommandsSection = (resourceSection)
      .children
      .whereType<i3config.Section>()
      .where((element) => element.name == 'subcommands')
      .firstOrNull;

  List<Command> subCommands = [];

  if (subCommandsSection != null) {
    subCommands = subCommandsSection.children
        .whereType<i3config.Section>()
        .map((e) => readCommand(e))
        .toList();
  }

  final templateSection = resourceSection.children
      .whereType<i3config.Section>()
      .where((element) => element.name == 'template')
      .firstOrNull;

  Template? template;
  if (templateSection != null) {
    template = Template(
      template: templateSection.properties['template'],
      vars: templateSection.children
          .whereType<i3config.Section>()
          .where((i3config.Section a) => a.module == 'vars')
          .first
          .properties,
    );
  }

  final properties = {
    ...propertyOverrides ?? {},
    ...resourceSection.properties,
  };

  return ResourceModel(
      id: resourceSection.modId,
      source: properties['source'] ?? '',
      destination: properties['destination'] ?? '',
      actions: actions,
      commands: subCommands,
      template: template,
      type:
          (properties.containsKey('type') && properties['type'] == 'directory')
              ? ResourceType.directory
              : ResourceType.file);
}

Package readPackage(i3config.Section packageSection) {
  packageSection.properties
      .requires(['name'], errorMessage: "package name cannot be empty");
  return Package(
    id: packageSection.modId,
    name: packageSection.properties['name'],
    manager: packageSection.properties['manager'] ?? '',
    version: packageSection.properties['version'] ?? '',
    scope: packageSection.properties['scope'] ?? '',
    status: packageSection.properties['status'],
    timestamp: packageSection.properties['timestamp'],
    sha256: packageSection.properties['sha256'],
  );
}

final registry = ResourceRegistry();

Config parseConfig(String contents) {
  i3config.I3Config i3Config;
  try {
    i3Config = i3config.I3ConfigParser(contents).parse();
  } catch (e, s) {
    throw ActionFailedException('Failed to parse config file', cause: e, stackTrace: s);
  }

  Config config = Config();

  for (var element in i3Config.elements) {
    if (element is i3config.Section) {
      switch (element.name) {
        case "group":
          try {
            element.properties.requires(["type"]);
          } on ArgumentError catch (e) {
            throw ActionFailedException("Group section:  ${e.message}");
          }

          final type = element.properties["type"]!;
          final items =
              element.children.whereType<i3config.ArrayElement>().firstOrNull;

          if (type == "package") {
            try {
              element.properties.requires([
                'manager',
              ]);
            } on ArgumentError catch (e) {
              throw ActionFailedException("Package group: ${e.message}");
            }

            if (items == null) {
              throw ActionFailedException(
                  "Package group: items property is required");
            }

            for (final item in items.values) {
              final nameVersion = item.toString().split('=');

              config.packages.add(Package(
                id: element.modId,
                name: nameVersion.elementAt(0),
                version: nameVersion.elementAtOrNull(1),
                manager: element.properties['manager']!,
                scope: element.properties['scope'] ?? 'global',
              ));
            }
          }

          if (type == "resource") {
            try {
              element.properties.requires(["destination"]);
            } on ArgumentError catch (e) {
              throw ActionFailedException(
                  "Group(resource) section:  ${e.message}");
            }

            final section = element.children
                .whereType<i3config.Section>()
                .firstWhereOrNull((s) => s.name == 'actions');
            if (section == null) {
              throw ArgumentError("Resource group requires actions");
            }

            List<Map<String, dynamic>> actions = [];
            final resourceId = registry.generateId('resource');

            actions = section.children
                .whereType<i3config.Section>()
                .mapIndexed((index, s) => readAction(s,
                    propertyOverrides: {
                      ...element.properties.except(["type"]),
                    },
                    resourceId: resourceId,
                    index: index))
                .map((a) => a.toJson())
                .toList();

            for (final item in items!.values) {
              //NOTE: when grouped, if an action has a destination property,  it will be used as a the destination directory when the action is executed.
              //so a  copy action  with a destination of ".foo" and the source "bar" will result in the file/directory "bar" being copied to ".foo/bar"
              //otherwise the destination property from the group will be used.
              actions = actions.map((action) {
                return {
                  ...action,
                  "properties": {
                    ...?action["properties"],
                    "destination": join(
                      action.containsKey("destination")
                          ? action["destination"] as String
                          : element.properties["destination"] as String,
                      item.toString(),
                    ).normalizePath()
                  }
                };
              }).toList();

              config.resources.add(ResourceModel.fromJson({
                'id': resourceId,
                ...element.properties.except(['type']),
                "destination": join(
                  element.properties["destination"] as String,
                  item.toString(),
                ).normalizePath(),
                "source": item.toString(),
                "actions": actions,
              }));
            }
          }

          break;
        case 'resources':
          final resources = (element)
              .children
              .whereType<i3config.Section>()
              .where((element) => element.name == 'resource');

          for (var child in resources) {
            config.resources.add(readresourceModel(child));
          }
          break;
        case 'resource':
          config.resources.add(readresourceModel(element));
          break;
        case 'commands':
          final commands = (element).children.whereType<i3config.Section>();

          for (var child in commands) {
            config.commands.add(readCommand(child));
          }
          break;
        case 'packages':
          final packages = (element)
              .children
              .whereType<i3config.Section>()
              .where((element) => element.name == 'package');

          for (var child in packages) {
            config.packages.add(readPackage(child));
          }
          break;
      }
    }
  }
  return config;
}

void exportConfiguration(Config config, String resourcePath) {
  final resource = fs.fs.file(resourcePath);
  final contents = config.toConfig();
  resource.writeAsStringSync(contents);
}
