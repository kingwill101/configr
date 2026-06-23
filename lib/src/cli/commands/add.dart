import 'dart:io';

import 'base_command.dart';
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

    for (final file in files) {
      await _addBlock(file);
    }
  }

  Future<void> _addBlock(String file) async {
    final dest =
        argResults?['destination'] as String? ??
        '~/.config/${p.basename(file)}';
    final type = argResults?['type'] as String? ?? 'copy';

    final block =
        '''
$type {
  source = "$file"
  destination = "$dest"
}
''';

    // Append to config file
    final configFile =
        runtime.config.configPath ?? p.join(runtime.workingDirectory, 'config');
    final f = runtime.fileSystem.file(configFile);

    if (await f.exists()) {
      final current = await f.readAsString();
      await f.writeAsString('$current\n$block\n');
    } else {
      await f.writeAsString('# Configr v2\n\n$block\n');
    }

    io.success('Added $type block for $file to configuration.');
  }
}
