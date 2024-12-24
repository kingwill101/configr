import 'dart:io';

import 'package:configr/commands/command.dart';

class EditCommand extends Command {
  EditCommand(super.configManager);

  @override
  Future<void> execute() async {
    await configManager.load();
    final editor =
        Platform.environment['EDITOR'] ?? Platform.environment['VISUAL'];

    if (editor == null) {
      print(
          'No default editor found. Please set the EDITOR or VISUAL environment variable.');
      return;
    }

    final editorParts = editor.split(' ');
    final editorCommand = editorParts.first;
    final editorArgs = [
      ...editorParts.skip(1),
      configManager.resolvedConfigPath
    ];

    try {
      final process = await Process.start(editorCommand, editorArgs,
          mode: ProcessStartMode.inheritStdio);

      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        print('Editor exited with code $exitCode');
      }
    } catch (e) {
      print('Error opening editor: $e');
      exit(1);
    }
  }
}
