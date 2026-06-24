# Configr Documentation

Configr is a powerful configuration management tool for dotfiles and system
configuration. It uses the i3config-format for declarative, block-based
configuration files.

## Quick Links

- [CLI Usage Guide](cli-usage.md) — Command reference and examples
- [Migration Guide](migration-guide.md) — Upgrading from v1 to v2
- [Tutorial](tutorial.md) — Getting started guide

## Action Blocks

Configr v2 uses **action blocks** — i3config-format blocks that each perform
a specific operation. All blocks support `source`, `destination`, and
block-specific properties.

| Block | Description |
|-------|-------------|
| [Alternatives](modules/alternatives-module.md) | Manages command alternatives (`update-alternatives`) |
| [Assert](modules/assert-module.md) | Validates conditions via shell commands |
| [Backup](backup.md) | Creates backup copies before modifications |
| [BlockInFile](modules/blockinfile-module.md) | Manages multi-line blocks in files |
| [Compress](compress.md) | Compresses files/directories into archives |
| [Copy](copy.md) | Copies files/directories to new locations |
| [Decompress](decompress.md) | Extracts files from archives |
| [Delete](delete.md) | Safely deletes files and directories |
| [Download](download.md) | Downloads files from remote URLs |
| [Echo](echo.md) | Prints messages to the console |
| [Execute](execute.md) | Executes shell commands |
| [File](file.md) | Creates/edits files with content |
| [Git](git.md) | Git repository operations |
| [Group](modules/group-module.md) | Manages system groups |
| [Hostname](modules/hostname-module.md) | Sets the system hostname |
| [LineInFile](modules/lineinfile-module.md) | Ensures a specific line in a file |
| [LocaleGen](modules/locale_gen-module.md) | Generates system locales |
| [Move](move.md) | Moves/renames files and directories |
| [Network](network.md) | Network connectivity testing |
| [Package](package.md) | Package management (apt, brew, dnf, docker, flatpak, npm, pacman, pamac, pip, snap, yum) |
| [Permissions](permissions.md) | Sets file permissions and ownership |
| [Rename](rename.md) | Renames files and directories |
| [Replace](modules/replace-module.md) | Replaces text using regular expressions |
| [Symlink](symlink.md) | Creates/manages symbolic links |
| [Sync](sync.md) | Bidirectional file synchronization |
| [Sysctl](modules/sysctl-module.md) | Manages kernel parameters |
| [Systemd](systemd.md) | Manages systemd services |
| [Template](template.md) | Renders template files with Liquid |
| [Timezone](modules/timezone-module.md) | Sets the system timezone |
| [Touch](touch.md) | Updates file timestamps |
| [User](modules/user-module.md) | Manages system user accounts |
| [Validate](validate.md) | Validates file contents and formats |

## Features

- **i3config v2 pipeline** — Full state-machine processing
- **Rollback** — All operations are reversible via lockfile
- **Lockfile** — SHA-256 checksums prevent redundant applies
- **Privilege escalation** — Sudo integration with persistent lock
- [**Built-in variables**](variables.md) — `$cwd`, `$configrDirs`, and dot-notation support
- [**Plugin system**](plugin-system.md) — Extend with custom block handlers (Dart + Lua)
- **Watch mode** — Auto-apply on file changes
- [**Terminal UI**](terminal-ui.md) — Task widgets, spinners, styled output, interactive prompts

## Architecture

```mermaid
flowchart LR
    Config[config file] --> Parser[i3config Parser]
    Parser --> AST[i3 AST]
    AST --> Processor[ConfigProcessor]
    Processor --> Handlers[Block Handlers]
    Handlers --> Execute[ActionBlock.execute]
    Execute --> Lockfile[config.lock.json]
    Lockfile --> Rollback[ActionBlock.rollback]
```

## Quick Start

```bash
# Initialize a v2 configuration
configr init --v2

# Apply configuration
configr apply --v2

# Rollback changes
configr rollback --v2
```
