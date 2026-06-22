import 'dart:io';

import 'base_command.dart';
import 'package:configr/src/models/file_model.dart';
import 'package:configr/src/models/action.dart';
import 'package:configr/src/utils/fs.dart';
import 'package:path/path.dart' as p;

class AddCommand extends BaseCommand {
  AddCommand() {
    argParser.addMultiOption('file', help: 'File to add to configuration');
    argParser.addOption(
      'type',
      abbr: 't',
      help: 'Block type for v2 mode (copy, file, symlink, etc.)',
      defaultsTo: 'copy',
    );
    argParser.addOption(
      'destination',
      abbr: 'd',
      help: 'Destination path for the block',
    );
  }

  @override
  String get name => 'add';

  @override
  String get description => 'Add a file to the configuration';

  @override
  void executeCommand() async {
    final files = argResults?['file'] as List<String>?;
    if (files == null || files.isEmpty) {
      io.error('Please specify a file to add.');
      exit(1);
    }

    final useV2 = configManager.configrConfig.useV2;

    for (final file in files) {
      if (useV2) {
        await _addV2(file);
      } else {
        await _addV1(file);
      }
    }
  }

  Future<void> _addV1(String file) async {
    await configManager.load();
    final basename = p.basename(file);
    final newFile = ResourceModel(
      id: 'added_${basename}_${DateTime.now().millisecondsSinceEpoch}',
      source: basename,
      destination: r'\{\{ config_path \}\}/' + basename,
      actions: [Action(type: 'copy')],
    );

    for (final existing in configManager.config.resources) {
      if (existing == newFile) {
        io.warn('File $file already exists in configuration.');
        return;
      }
    }
    configManager.config.resources.add(newFile);
    configManager.saveConfig();
    io.success('Added $file to configuration.');
  }

  Future<void> _addV2(String file) async {
    final dest =
        argResults?['destination'] as String? ??
        '~/.config/${p.basename(file)}';
    final type = argResults?['type'] as String? ?? 'copy';

    // Determine destination -- use basename if no explicit destination
    final block =
        '''
$type {
  source = "$file"
  destination = "$dest"
}
''';

    // Append to config file
    final configFile =
        configManager.configrConfig.configPath ??
        p.join(configManager.localPath!, 'config');
    final f = fs.file(configFile);

    if (await f.exists()) {
      final current = await f.readAsString();
      await f.writeAsString('$current\n$block\n');
    } else {
      await f.writeAsString('# Configr v2\n\n$block\n');
    }

    io.success('Added $type block for $file to configuration.');
  }
}
