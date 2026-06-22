import 'dart:io';

import 'base_command.dart';

class EditCommand extends BaseCommand {
  @override
  String get name => 'edit';

  @override
  String get description => 'Edit configuration file';

  @override
  void executeCommand() async {
    final editor =
        Platform.environment['EDITOR'] ?? Platform.environment['VISUAL'];

    if (editor == null) {
      io.error(
        'No default editor found. Please set the EDITOR or VISUAL '
        'environment variable.',
      );
      return;
    }

    final configPath =
        configManager.configrConfig.configPath ??
        '${configManager.fileSystem.currentDirectory.path}/config';

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
      exit(1);
    }
  }
}
