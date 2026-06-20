import 'dart:io';

import 'base_command.dart';
import 'package:configr/src/models/file_model.dart';
import 'package:configr/src/models/action.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:path/path.dart' as p;

class AddCommand extends BaseCommand {
  AddCommand() {
    argParser.addMultiOption('file', help: 'File to add to configuration');
  }

  @override
  String get name => 'add';
  
  @override
  String get description => 'Add a file to the configuration';

  @override
  void executeCommand() async {
    final files = argResults?['file'] as List<String>?;
    if (files == null || files.isEmpty) {
      logger.severe('Error: Please specify a file to add.');
      exit(1);
    }
    
    for (final file in files) {
      await configManager.load();
      final basename = p.basename(file);
      final newFile = ResourceModel(
          id: 'added_${basename}_${DateTime.now().millisecondsSinceEpoch}',
          source: basename,
          destination: r'\{\{ config_path \}\}/' + basename,
          actions: [Action(type: 'copy')]);

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
}
