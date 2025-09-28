// bin/main.dart

import 'dart:io';

import 'package:args/args.dart';
import 'package:configr/commands/add.dart';
import 'package:configr/commands/apply.dart';
import 'package:configr/commands/command.dart';
import 'package:configr/commands/diff.dart';
import 'package:configr/commands/edit.dart';
import 'package:configr/commands/format.dart';
import 'package:configr/commands/init.dart';
import 'package:configr/commands/rollback.dart';
import 'package:configr/commands/status.dart';
import 'package:configr/config_manager.dart';
import 'package:configr/utils/fs.dart';
import 'package:configr/utils/logging.dart';
import 'package:configr/utils/privellage_escallation.dart';

void main(List<String> arguments) async {
  initLogging();

  // final tracer = globalTracerProvider.getTracer('instrumentation-name');
  // final span = tracer.startSpan('main');
  final parser = ArgParser()
    ..addCommand('init')
    ..addCommand(
      'apply',
      ArgParser()..addFlag(
        'force',
        abbr: 'f',
        help: 'Force apply all resources regardless of state',
        defaultsTo: false,
      ),
    )
    ..addCommand('diff')
    ..addCommand('format')
    ..addCommand('add')
    ..addCommand('edit')
    ..addCommand('status')
    ..addCommand(
      'rollback',
      ArgParser()..addOption(
        'count',
        abbr: 'n',
        help: 'Number of most recent resources to rollback',
        valueHelp: 'number',
      ),
    )
    ..addOption('config', abbr: 'c', help: 'Path to the configuration file')
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    );
  ArgResults argResults;
  try {
    argResults = parser.parse(arguments);
  } catch (e) {
    logger.severe('Error: $e\n');
    printUsage(parser);
    exit(1);
  }

  if (argResults['help'] || argResults.command == null) {
    printUsage(parser);
    return;
  }

  final String configPath = argResults['config'] ?? 'config';
  final String? commandName = argResults.command!.name;

  final privilegeEscalation = InteractiveSudoEscalation();
  final configManager = ConfigManager(
    repoUrl: 'https://github.com/yourusername/dotfiles.git',
    path: fs.currentDirectory.path,
    fileSystem: fs,
    privilegeEscalation: privilegeEscalation,
    configPath: configPath,
  );

  try {
    Command command;
    switch (commandName) {
      case 'init':
        command = InitCommand(configManager);
        break;
      case 'apply':
        final force = argResults.command!['force'] as bool;
        command = ApplyCommand(configManager, force: force);
        break;
      case 'diff':
        command = DiffCommand(configManager);
        break;
      case 'add':
        if (argResults.command!.rest.isEmpty) {
          print('Error: Please specify a file to add.');
          exit(-1);
        }
        command = AddCommand(configManager, argResults.command!.rest[0]);
        break;
      case 'edit':
        command = EditCommand(configManager);
        break;
      case 'status':
        command = StatusCommand(configManager);
        break;
      case 'format':
        command = FormatCommand(configManager);
        break;
      case 'rollback':
        final count = argResults.command!['count'] != null
            ? int.tryParse(argResults.command!['count'])
            : null;
        command = RollbackCommand(configManager, count: count);
        break;
      default:
        logger.warning('Unknown command: $commandName');
        printUsage(parser);
        exit(-1);
    }
    await command.execute();
  } catch (e, stackTrace) {
    logger.severe('unable to setup: $e', e, stackTrace);
    exit(-1);
  }
}

void printUsage(ArgParser parser) {
  print('Usage: dart bin/main.dart <command> [arguments]');
  print(parser.usage);
}
