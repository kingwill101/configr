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

1. Create a config file:

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

2. Apply your configuration:

```bash
configr apply
```

## Documentation

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
