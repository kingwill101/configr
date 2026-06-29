# CLI Usage Guide

## Overview

Configr is driven from the `configr` command. Use it to initialize configs,
preview changes, apply locally or remotely, run named commands, inspect status,
and roll back previous applies.

## Basic Usage

```bash
# Show available commands and global options
configr --help

# Show help for a specific command
configr <command> --help

# Run a command
configr <command> [options]
```

## Global Options

| Option | Description |
|--------|-------------|
| `-c, --config <path>` | Path to the configuration file (defaults to `config`) |
| `--version` | Print embedded version and build metadata |
| `-d, --debug` | Enable debug output with timestamps |
| `--dry-run` | Show what would be done without making changes |
| `--plugin-dir <path>` | Directory to discover plugins from (repeatable) |
| `-v, --verbose` | Increase verbosity (-v, -vv, -vvv) |
| `-q, --quiet` | Suppress output |
| `-n, --no-interaction` | Disable interactive prompts |
| `--ansi / --no-ansi` | Force ANSI output |
| `--generate-completion` | Generate shell completion script |
| `--host <hostname>` | SSH host for remote execution |
| `--ssh-port <port>` | SSH port (default: 22) |
| `--ssh-user <username>` | SSH username (default: root) |
| `--ssh-password <password>` | SSH password |
| `--ssh-key <path>` | Path to SSH private key |
| `--ssh-key-passphrase <passphrase>` | Passphrase for SSH private key |

## Available Commands

### `init`

Initialize a new configuration repository with a template config file.

```bash
configr init
```

Generates a `config` file with example blocks for copy, file, symlink,
template, package, execute, and git operations.

### `apply`

Apply configuration changes to the system.

```bash
# Apply configuration
configr apply

# Force re-apply (ignore lockfile)
configr apply --force

# Preview mode (no changes made)
configr apply --dry-run

# Stop at first error
configr apply --fail-fast

# Watch for changes and re-apply automatically
configr apply --watch

# Apply to a remote host via SSH
configr apply --host server.example.com --ssh-user deploy

# Apply with SSH key authentication
configr apply --host db.internal --ssh-key ~/.ssh/id_rsa
```

### `rollback`

Rollback applied changes using the lockfile.

```bash
# Rollback all changes
configr rollback

# Rollback specific number of operations
configr rollback --count 3
```

### `diff`

Show differences between current and target configuration by listing
parsed action blocks with their status.

```bash
configr diff
```

### `status`

Show the current status of all configured action blocks.

```bash
configr status
```

Groups blocks by type and shows each block's status (pending/completed/failed).

### `format`

Format the configuration file in-place.

```bash
configr format
```

Re-serializes the config through the i3config format boundary,
producing clean, consistently-formatted output.

### `add`

Add a file to the configuration by appending a block.

```bash
# Add a copy block
configr add --file ~/.bashrc

# Specify block type and destination
configr add --file ~/.config/starship.toml --type template --destination "~/.config/starship.toml"
```

### `edit`

Open the configuration file in your default editor (uses `$EDITOR` or `$VISUAL`).

```bash
configr edit
```

### `watch`

Watch configuration files and apply changes automatically.

```bash
configr watch

# Apply once and exit
configr watch --once
```

### `run`

Run a named command from the top-level `commands {}` section.

```i3
commands {
  command "test" {
    command = "make"
    parameters "test"
  }
}
```

```bash
# Run the command
configr run test

# Append extra arguments to the configured parameters
configr run test -- --coverage

# Run from a specific directory
configr run test --working-directory /path/to/project

# Run through SSH using the global remote execution flags
configr run test --host server.example.com --ssh-user deploy
```

## Configuration File Format

Configr uses i3config-format blocks:

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

# Resource-scoped blocks
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
configr init
configr add --file ~/.bashrc --destination "~/.bashrc"
configr apply

# Dry-run to preview changes
configr apply --dry-run

# Rollback if something went wrong
configr rollback
```

## Error Handling

The CLI provides clear error messages when:
- Configuration files cannot be found or parsed
- Commands fail during execution
- Privilege escalation is required but unavailable
- Invalid arguments are provided
