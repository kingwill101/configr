import 'dart:io';

import 'package:configr/commands/command.dart';
import 'package:configr/utils/fs.dart';
import 'package:path/path.dart';

class InitCommand extends Command {
  InitCommand(super.configManager);

  @override
  Future<void> execute() async {
    final possibleConfigPaths = [
      join(configManager.localPath!, 'config.json'),
      join(configManager.localPath!, 'config'),
    ];

    for (var configPath in possibleConfigPaths) {
      if (await fs.file(configPath).exists()) {
        print(
            'Configuration file ${basename(configPath)} already exists. Do you want to overwrite it? (y/n)');
      }

      final response = stdin.readLineSync();
      if (response?.toLowerCase() != 'y') {
        print('Aborted.');
        return;
      }
    }

    print('Choose configuration format:');
    print('1. I3-like format (default)');
    print('2. JSON format');
    print('Enter your choice (1 or 2), or press Enter for default:');

    final formatChoice = stdin.readLineSync()?.trim();

    String configContent;
    if (formatChoice == '2') {
      configContent = '''
{
  "config": {
    "location": [
      {
        "platform": "linux",
        "destination": "~/.config"
      }
    ],
    "destination": "~/.config"
  },
  "files": [],
  "packages": [],
  "commands": [],
  "scripts": {
    "pre_apply": [],
    "post_apply": []
  }
}
''';
    } else {
      // Default to i3-like format
      configContent = '''
config {
  # default unless overridden by a location section
  destination = "~/.config"
}

files {
}

packages {
}

commands {
}

scripts {
  pre_apply {
  }

  post_apply {
  }
}
''';
    }

    final f =
        configManager.fileSystem.file(join(configManager.localPath!, 'config'));
    await f.writeAsString(configContent);

    print('Initialized empty configuration at ${f.path}');
  }
}
