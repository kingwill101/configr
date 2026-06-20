# CLI Usage Guide

## Overview

Configr uses Dart's CommandRunner framework to provide a modern, structured command-line interface. All commands are automatically registered and provide built-in help functionality.

## Basic Usage

```bash
# Show available commands and global options
dart bin/main.dart --help

# Show help for a specific command
dart bin/main.dart <command> --help

# Execute a command with options
dart bin/main.dart <command> [options] [arguments]
```

## Global Options

All commands support these global options:

- `-c, --config <path>`: Path to the configuration file (defaults to "config")
- `-h, --help`: Print usage information

## Available Commands

### `init`
Initialize a new configuration repository.

```bash
dart bin/main.dart init
```

### `apply`
Apply configuration changes to the system.

```bash
# Apply with default settings
dart bin/main.dart apply

# Force apply all resources regardless of state
dart bin/main.dart apply --force
```

### `add`
Add files to the configuration.

```bash
# Add a single file
dart bin/main.dart add --file <path>

# Add multiple files
dart bin/main.dart add --file <path1> --file <path2>
```

### `status`
Show the current status of the configuration.

```bash
dart bin/main.dart status
```

### `diff`
Show differences between current and target configuration.

```bash
dart bin/main.dart diff
```

### `edit`
Edit the configuration file.

```bash
dart bin/main.dart edit
```

### `format`
Format the configuration file.

```bash
dart bin/main.dart format
```

### `rollback`
Rollback configuration changes.

```bash
# Rollback last change
dart bin/main.dart rollback

# Rollback specific number of changes
dart bin/main.dart rollback --count 3
```

## Examples

### Basic Workflow

```bash
# Initialize a new configuration
dart bin/main.dart init

# Add some files
dart bin/main.dart add --file ~/.bashrc --file ~/.vimrc

# Check status
dart bin/main.dart status

# Apply configuration
dart bin/main.dart apply

# Check what would change
dart bin/main.dart diff
```

### Using Custom Config File

```bash
# Use a custom configuration file
dart bin/main.dart --config /path/to/config apply --force
```

### Getting Help

```bash
# General help
dart bin/main.dart --help

# Command-specific help
dart bin/main.dart apply --help
dart bin/main.dart rollback --help
```

## Error Handling

The CLI provides clear error messages and usage information when:

- Invalid commands are provided
- Required arguments are missing
- Invalid option values are used
- Configuration files cannot be found or parsed

## Interactive Features

Some commands support interactive input:

- **Password prompts**: Automatically handled with secure input
- **Confirmations**: Clear prompts for destructive operations
- **Progress indication**: Real-time progress bars and status updates

## Performance

The new CLI implementation provides:

- **Smooth progress bars**: Unicode-based progress indicators
- **No flickering**: Efficient terminal rendering
- **Fast startup**: Optimized command registration
- **Responsive UI**: Real-time status updates
