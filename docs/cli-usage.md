# CLI Usage Guide

## Overview

Configr uses an Artisanal-powered command-line interface for styled output,
progress indicators, and interactive prompts.

## Basic Usage

```bash
# Show available commands and global options
configr --help

# Show help for a specific command
configr <command> --help

# Execute a command
configr <command> [options]
```

> **Note**: Compile the binary first: `dart compile exe bin/configr.dart -o build/cli/linux_x64/bundle/bin/configr`

## Global Options

| Option | Description |
|--------|-------------|
| `-c, --config <path>` | Path to the configuration file (defaults to `config`) |
| `--v2` | Use the v2 i3config-based ActionBlock pipeline |
| `-d, --debug` | Enable debug output with timestamps |
| `--dry-run` | Show what would be done without making changes |
| `--plugin-dir <path>` | Directory to discover plugins from (repeatable) |
| `-v, --verbose` | Increase verbosity (-v, -vv, -vvv) |
| `-q, --quiet` | Suppress output |
| `-n, --no-interaction` | Disable interactive prompts |
| `--ansi / --no-ansi` | Force ANSI output |
| `--generate-completion` | Generate shell completion script |

## Available Commands

### `init`

Initialize a new configuration repository with a template config file.

```bash
configr init --v2
```

Generates a `config` file with example blocks for copy, file, symlink,
template, package, execute, and git operations.

### `apply`

Apply configuration changes to the system.

```bash
# Apply configuration
configr apply --v2

# Force re-apply (ignore lockfile)
configr apply --v2 --force

# Preview mode (no changes made)
configr apply --v2 --dry-run

# Stop at first error
configr apply --v2 --fail-fast

# Watch for changes and re-apply automatically
configr apply --v2 --watch
```

### `rollback`

Rollback applied changes using the lockfile.

```bash
# Rollback all changes
configr rollback --v2

# Rollback specific number of operations
configr rollback --v2 --count 3
```

### `diff`

Show differences between current and target configuration by listing
parsed action blocks with their status.

```bash
configr diff --v2
```

### `status`

Show the current status of all configured action blocks.

```bash
configr status --v2
```

Groups blocks by type and shows each block's status (pending/completed/failed).

### `format`

Format the configuration file in-place.

```bash
configr format --v2
```

Re-serializes the config through the i3config v2 format boundary,
producing clean, consistently-formatted output.

### `add`

Add a file to the configuration by appending a block.

```bash
# Add a copy block (default)
configr add --v2 --file ~/.bashrc

# Specify block type and destination
configr add --v2 --file ~/.config/starship.toml --type template --destination "~/.config/starship.toml"
```

### `edit`

Open the configuration file in your default editor (uses `$EDITOR` or `$VISUAL`).

```bash
configr edit --v2
```

### `watch`

Watch configuration files and apply changes automatically.

```bash
configr watch --v2

# Apply once and exit
configr watch --v2 --once
```

## Configuration File Format

Configr v2 uses i3config-format blocks:

```i3
# Copy a file
copy {
  source = "dotfiles/bashrc"
  destination = "~/.bashrc"
}

# Create a file with content
file {
  source = "~/.config/configr/user-config"
  content = "# user preferences"
  operation = "create"
}

# Template rendering
template {
  source = "templates/starship.toml.liquid"
  destination = "~/.config/starship.toml"
}

# Execute a command
execute {
  command = "echo 'Setup complete!'"
}

# Nested blocks (v1-compatible)
resource {
  source = "myapp.conf"
  destination = "/etc/myapp.conf"
  actions {
    copy { }
    permissions { mode = "644" }
  }
}
```

## Examples

```bash
# Initialize, add files, and apply
configr init --v2
configr add --v2 --file ~/.bashrc --destination "~/.bashrc"
configr apply --v2

# Dry-run to preview changes
configr apply --v2 --dry-run

# Rollback if something went wrong
configr rollback --v2
```

## Error Handling

The CLI provides clear error messages when:
- Configuration files cannot be found or parsed
- Commands fail during execution
- Privilege escalation is required but unavailable
- Invalid arguments are provided
