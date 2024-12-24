import 'dart:io';

import 'package:configr/commands/command.dart';
import 'package:configr/models/file_model.dart';
import 'package:configr/models/action.dart';
import 'package:configr/utils/logging.dart';
import 'package:path/path.dart' as p;

class AddCommand extends Command {
  final String file;

  AddCommand(super.configManager, this.file);

  @override
  Future<void> execute() async {
    await configManager.load();
    final basename = p.basename(file);
    final newFile = ResourceModel(
        source: '"$basename"',
        destination: '"\\{\\{ config_path }}/$basename"',
        actions: [
          Action(
            type: 'copy',
          )
        ]);

    for (final existing in configManager.config.resources) {
      if (existing == newFile) {
        logger.warning('File $file already exists in configuration.');
        exit(0);
      }
    }
    configManager.config.resources.add(newFile);
    configManager.saveConfig();
    logger.info('Added $file to configuration.');
  }
}
