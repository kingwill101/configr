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

Download the latest pre-built binary for your platform from the [Releases page](https://github.com/kingwill101/configr/releases).

```bash
# Download and make executable
chmod +x configr

# (Optional) Move to a directory on your PATH
sudo mv configr /usr/local/bin/
```

> Alternatively, build from source: clone the repo, run `dart compile exe bin/configr.dart -o configr`, and place the resulting binary on your PATH.

## Quick Start

### 1. Initialize Configuration

```bash
# Initialize a new configuration repository
configr init
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
configr add --file ~/.bashrc

# Add multiple files
configr add --file ~/.vimrc --file ~/.gitconfig
```

4. Apply your configuration:

```bash
# Apply with default settings
configr apply

# Force apply all resources
configr apply --force
```

5. Check status and manage your configuration:

```bash
# View current status
configr status

# See what would change
configr diff

# Rollback changes if needed
configr rollback

# Rollback specific number of operations
configr rollback --count 3
```

## CLI Usage

### Available Commands

```bash
# Show all available commands
configr --help

# Get help for a specific command
configr <command> --help
```

### Global Options

- `-c, --config <path>`: Path to configuration file (defaults to "config")
- `-h, --help`: Print usage information

### Command Examples

```bash
# Initialize configuration
configr init

# Add files to configuration
configr add --file ~/.bashrc --file ~/.vimrc

# Apply configuration
configr apply --force

# Check status
configr status

# View differences
configr diff

# Edit configuration
configr edit

# Format configuration
configr format

# Rollback changes
configr rollback --count 2

# Rollback all changes
configr rollback
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
