import 'package:configr/exceptions.dart';
import 'package:configr/extensions/string.dart';
import 'package:configr/models/action.dart';
import 'package:configr/models/command.dart';
import 'package:configr/models/config.dart';
import 'package:configr/models/file_model.dart';
import 'package:configr/models/package.dart';
import 'package:configr/models/template.dart';
import 'package:configr/utils/fs.dart' as fs;
import 'package:i3config/i3config.dart' as i3config;

Action readAction(i3config.Section actionSection) {
  final actions = actionSection.children.whereType<i3config.Section>();

  return Action(
      type: actionSection.module,
      backupPath: actionSection.properties['backupPath'],
      status: actionSection.properties['status'],
      timestamp: actionSection.properties['timestamp'],
      sha256: actionSection.properties['sha256'],
      properties: actionSection.properties,
      actions: actions.map((a) => readAction(a)).toList());
}

Command readCommand(i3config.Section commandSection) {
  final args = commandSection.properties['parameters'] ?? [];

  List<String> params = [];
  if (args is String) {
    params = args.split(' ');
  }

  return Command(
    name: commandSection.moduleName,
    command: commandSection.properties['command'],
    parameters: params,
    status: commandSection.properties['status'],
    timestamp: commandSection.properties['timestamp'],
    sha256: commandSection.properties['sha256'],
  );
}

ResourceModel readresourceModel(i3config.Section resourceSection) {
  final actionsSection = resourceSection.children
      .whereType<i3config.Section>()
      .where((element) => element.name == 'actions')
      .firstOrNull;
  List<Action> actions = [];

  if (actionsSection != null) {
    actions = actionsSection.children
        .whereType<i3config.Section>()
        .map((e) => readAction(e))
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
  final properties = resourceSection.properties;
  return ResourceModel(
      source: resourceSection.properties['source'] ?? '',
      destination: resourceSection.properties['destination'] ?? '',
      actions: actions,
      commands: subCommands,
      template: template,
      type:
          (properties.containsKey('type') && properties['type'] == 'directory')
              ? ResourceType.directory
              : ResourceType.file,
      recursive: properties.containsKey('recursive') &&
          (properties['recursive'] as String).unquote() == 'true');
}

Package readPackage(i3config.Section packageSection) {
  return Package(
    name: packageSection.properties['name'] ?? '',
    manager: packageSection.properties['manager'] ?? '',
    version: packageSection.properties['version'] ?? '',
    scope: packageSection.properties['scope'] ?? '',
    status: packageSection.properties['status'],
    timestamp: packageSection.properties['timestamp'],
    sha256: packageSection.properties['sha256'],
  );
}

Config parseConfig(String contents) {
  i3config.I3Config i3Config;
  try {
    i3Config = i3config.I3ConfigParser(contents).parse();
  } catch (e, s) {
    throw ActionFailedException('Failed to parse config file', e, s);
  }

  Config config = Config();
  for (var element in i3Config.elements) {
    if (element is i3config.Section) {
      switch (element.name) {
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
