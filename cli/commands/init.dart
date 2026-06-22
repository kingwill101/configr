import 'base_command.dart';
import 'package:configr/src/utils/fs.dart';
import 'package:path/path.dart';

class InitCommand extends BaseCommand {
  @override
  String get name => 'init';

  @override
  String get description => 'Initialize a new configuration repository';

  @override
  void executeCommand() async {
    final configDir =
        runtime.config.localPath ?? runtime.fileSystem.currentDirectory.path;
    final configFile = join(configDir, 'config');

    if (await fs.file(configFile).exists()) {
      io.warn('Configuration file already exists at $configFile');
      if (!io.confirm('Overwrite it?', defaultValue: false)) {
        io.info('Aborted.');
        return;
      }
    }

    final content = _v2Template();

    final f = runtime.fileSystem.file(configFile);
    await f.writeAsString(content);

    io.success('Initialized v2 configuration at ${f.path}');
  }

  /// Generates a v2 i3config-format template with example blocks.
  String _v2Template() => '''
# Configr v2 configuration
# Uses i3config-format blocks for declarative system configuration.

config {
  destination = "~/.config"
}

# Copy files and directories
copy {
  source = "dotfiles/bashrc"
  destination = "~/.bashrc"
}

# Create files with content
file {
  source = "~/.config/configr/user-config"
  content = "# user preferences go here"
  operation = "create"
}

# Create symbolic links
symlink {
  source = "dotfiles/gitconfig"
  destination = "~/.gitconfig"
}

# Template rendering
template {
  source = "templates/starship.toml.liquid"
  destination = "~/.config/starship.toml"
}

# Package management
package {
  source = "curl git"
  operation = "install"
  package_manager = "apt"
}

# Execute commands
execute {
  command = "echo 'Setup complete!'"
}

# Git operations
git {
  source = "https://github.com/user/repo.git"
  destination = "~/projects/repo"
  operation = "clone"
}
''';
}
