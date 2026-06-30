# configr

A flexible configuration management tool that helps you manage dotfiles, system configurations, and file operations with rollback support.

## Features

- File Operations
  - Copy files and directories
  - Create backups before modifications
  - Set permissions and ownership
  - Create symbolic links
  - Compress/decompress archives

- Templates
  - Generate files from templates
  - Variable substitution
  - Support for multiple template formats

- Validation
  - Format validation (JSON, YAML, etc.)
  - Checksum verification

- Safety Features
  - Automatic backups
  - Rollback on failure
  - Dry run mode
  - File integrity checks

## Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/configr.git

# Build the project
cd configr
dart pub get
dart compile exe bin/configr.dart -o configr
```

## Quick Start

### 1. Initialize Configuration

```bash
# Initialize a new configuration repository
dart bin/main.dart init
```

### 2. Create a config file:

```
resources {
  resource {
    source "bashrc"
    destination "~/.bashrc"

    actions {
      backup {
        backup_path "~/.bashrc.bak"
      }
      copy {}
      permissions {
        mode "644"
      }
    }
  }
}
```

3. Add files to your configuration:

```bash
# Add a single file
dart bin/main.dart add --file ~/.bashrc

# Add multiple files
dart bin/main.dart add --file ~/.vimrc --file ~/.gitconfig
```

4. Apply your configuration:

```bash
# Apply with default settings
dart bin/main.dart apply

# Force apply all resources
dart bin/main.dart apply --force
```

5. Check status and manage your configuration:

```bash
# View current status
dart bin/main.dart status

# See what would change
dart bin/main.dart diff

# Rollback changes if needed
dart bin/main.dart rollback

# Rollback specific number of operations
dart bin/main.dart rollback --count 3
```

## CLI Usage

### Available Commands

```bash
# Show all available commands
dart bin/main.dart --help

# Get help for a specific command
dart bin/main.dart <command> --help
```

### Global Options

- `-c, --config <path>`: Path to configuration file (defaults to "config")
- `-h, --help`: Print usage information

### Command Examples

```bash
# Initialize configuration
dart bin/main.dart init

# Add files to configuration
dart bin/main.dart add --file ~/.bashrc --file ~/.vimrc

# Apply configuration
dart bin/main.dart apply --force

# Check status
dart bin/main.dart status

# View differences
dart bin/main.dart diff

# Edit configuration
dart bin/main.dart edit

# Format configuration
dart bin/main.dart format

# Rollback changes
dart bin/main.dart rollback --count 2

# Rollback all changes
dart bin/main.dart rollback
```

### Output Format

The CLI provides clean, text-focused output:

```
[module-id] Starting: Operation description
[module-id] Progress: 50% - Processing...
[module-id] Completed: Operation completed successfully
```

## Documentation

- [CLI Usage Guide](docs/cli-usage.md)
- [Terminal UI System](docs/terminal-ui.md)
- [Developer Guide](docs/developer/command-creation.md)
- [Migration Guide](docs/migration-guide.md)
- [Module Documentation](docs/modules/README.md)
- [Getting Started Tutorial](docs/modules/tutorial.md)
- [Configuration Format](docs/basics.md)

## Examples

Check out the [examples](examples) directory for common configuration scenarios:

- Basic file operations
- Template usage
- Archive management
- System configuration
- Dotfiles management

## Development

```bash
# Run tests
dart test

# Run specific test file
dart test test/config_management_test.dart

```

## License

MIT License - see [LICENSE](LICENSE) for details


## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

For more information, see [CONTRIBUTING.md](CONTRIBUTING.md)
