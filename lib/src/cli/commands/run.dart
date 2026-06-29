import 'package:configr/src/cli/cli_exit_exception.dart';
import 'package:configr/src/utils/logging.dart';

import 'base_command.dart';

class RunCommand extends BaseCommand {
  RunCommand() {
    argParser.addFlag(
      'shell',
      help: 'Run the command through the platform shell',
      defaultsTo: false,
    );
    argParser.addOption(
      'working-directory',
      abbr: 'C',
      help: 'Working directory for the command',
      valueHelp: 'path',
    );
  }

  @override
  String get name => 'run';

  @override
  String get description => 'Run a named command from the config';

  @override
  Future<void> executeCommand() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      io.error('Missing command name.');
      io.line('Usage: configr run <name> [-- extra args]');
      throw CliExitException(64);
    }

    final name = rest.first;
    final extraArgs = rest.skip(1).toList();
    final runInShell = argResults?['shell'] as bool? ?? false;
    final workingDirectory = argResults?['working-directory'] as String?;

    io.title('Run Command');
    io.info('Command: $name');

    try {
      final result = await runtime.runNamedCommand(
        name,
        extraArgs: extraArgs,
        commandWorkingDirectory: workingDirectory,
        runInShell: runInShell,
        onOutput: (line, isStderr) {
          if (isStderr) {
            io.error(line);
          } else {
            io.line(line);
          }
        },
      );

      if (result.exitCode == 0) {
        io.success('Command "$name" completed successfully.');
      } else {
        io.error('Command "$name" failed with exit code ${result.exitCode}.');
        throw CliExitException(result.exitCode);
      }
    } catch (e, stackTrace) {
      if (e is CliExitException) rethrow;
      io.error('Run failed: $e');
      logger.error('Run command failed: $e', e, stackTrace);
      throw CliExitException(1);
    }
  }
}
