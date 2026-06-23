import 'dart:io';

import 'package:configr/src/cli/cli_exit_exception.dart';
import 'base_command.dart';

class EditCommand extends BaseCommand {
  @override
  String get name => 'edit';

  @override
  String get description => 'Edit configuration file';

  @override
  Future<void> executeCommand() async {
    final editor =
        Platform.environment['EDITOR'] ?? Platform.environment['VISUAL'];

    if (editor == null) {
      io.error(
        'No default editor found. Please set the EDITOR or VISUAL '
        'environment variable.',
      );
      return;
    }

    final cfg = runtime.config;
    final configPath = cfg.configPath ?? '${runtime.workingDirectory}/config';

    final editorParts = editor.split(' ');
    final editorCommand = editorParts.first;
    final editorArgs = [...editorParts.skip(1), configPath];

    try {
      final process = await Process.start(
        editorCommand,
        editorArgs,
        mode: ProcessStartMode.inheritStdio,
      );

      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        io.warn('Editor exited with code $exitCode');
      }
    } catch (e) {
      io.error('Error opening editor: $e');
      throw CliExitException(1);
    }
  }
}
