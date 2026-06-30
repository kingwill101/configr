# Configr Documentation

Configr is a powerful configuration management tool for dotfiles and system
configuration. It uses the i3config-format for declarative, block-based
configuration files.

## Quick Links

- [CLI Usage Guide](getting-started/cli-usage.md) — Command reference and examples
- [Migration Guide](getting-started/migration-guide.md) — Upgrading from v1 to v2
- [Tutorial](getting-started/tutorial.md) — Getting started guide
- [Architecture](guides/architecture.md) — Core abstractions and design decisions
- [Secrets Management](guides/secrets.md) — Provider-agnostic secret resolution
- [Remote Execution](guides/remote-execution.md) — SSH transport for remote machines
- [Multi-Host Execution](guides/multi-host.md) — Inventory, strategies, per-host lockfiles, remote rollback
- [SSH VM Integration Guide](guides/ssh-vm-guide.md) — Launch Docker VMs and apply configs over SSH

## Action Blocks

Configr v2 uses **action blocks** — i3config-format blocks that each perform
a specific operation. All blocks support `source`, `destination`, and
block-specific properties.

| Block | Description |
|-------|-------------|
| [Alternatives](blocks/alternatives-module.md) | Manages command alternatives (`update-alternatives`) |
| [Assert](blocks/assert-module.md) | Validates conditions via shell commands |
| [AuthorizedKey](blocks/authorized_key.md) | Manages SSH authorized_keys entries |
| [Backup](blocks/backup.md) | Creates backup copies before modifications |
| [BlockInFile](blocks/blockinfile-module.md) | Manages multi-line blocks in files |
| [Compress](blocks/compress.md) | Compresses files/directories into archives |
| [Copy](blocks/copy.md) | Copies files/directories to new locations |
| [Cron](blocks/cron.md) | Manages cron job entries |
| [Debug](blocks/debug.md) | Prints debug messages to the console |
| [Decompress](blocks/decompress.md) | Extracts files from archives |
| [Delete](blocks/delete.md) | Safely deletes files and directories |
| [Download](blocks/download.md) | Downloads files from remote URLs |
| [Echo](blocks/echo.md) | Prints messages to the console |
| [Execute](blocks/execute.md) | Executes shell commands |
| [Fail](blocks/fail.md) | Fails execution with a custom error message |
| [Fetch](blocks/fetch.md) | Fetches files from the target to the local machine |
| [File](blocks/file.md) | Creates/edits files with content |
| [Firewalld](blocks/firewalld.md) | Manages firewalld services, ports, and rules (Linux) |
| [GatherFacts](blocks/gather_facts.md) | Collects system facts into context variables |
| [Git](blocks/git.md) | Git repository operations |
| [Group](blocks/group-module.md) | Manages system groups |
| [Hostname](blocks/hostname-module.md) | Sets the system hostname |
| [KnownHosts](blocks/known_hosts.md) | Manages SSH known_hosts entries |
| [LineInFile](blocks/lineinfile-module.md) | Ensures a specific line in a file |
| [LocaleGen](blocks/locale_gen-module.md) | Generates system locales |
| [Mount](blocks/mount.md) | Manages mount points and fstab entries |
| [Move](blocks/move.md) | Moves/renames files and directories |
| [Network](blocks/network.md) | Network connectivity testing |
| [Package](blocks/package.md) | Package management (apt, brew, dnf, docker, flatpak, npm, pacman, pamac, pip, snap, yum) |
| [Pause](blocks/pause.md) | Pauses execution for a specified duration |
| [Permissions](blocks/permissions.md) | Sets file permissions and ownership |
| [Raw](blocks/raw.md) | Executes raw shell commands |
| [Rename](blocks/rename.md) | Renames files and directories |
| [Replace](blocks/replace-module.md) | Replaces text using regular expressions |
| [Script](blocks/script.md) | Copies and executes local scripts on the target |
| [Service](blocks/service.md) | Manages system services across init systems |
| [SetFact](blocks/set_fact.md) | Sets key/value pairs as context variables |
| [Slurp](blocks/slurp.md) | Reads files and base64-encodes their content |
| [Stat](blocks/stat.md) | Retrieves file/directory statistics |
| [Symlink](blocks/symlink.md) | Creates/manages symbolic links |
| [Sync](blocks/sync.md) | Bidirectional file synchronization |
| [Sysctl](blocks/sysctl-module.md) | Manages kernel parameters |
| [Systemd](blocks/systemd.md) | Manages systemd services |
| [Template](blocks/template.md) | Renders template files with Liquid |
| [Timezone](blocks/timezone-module.md) | Sets the system timezone |
| [Touch](blocks/touch.md) | Updates file timestamps |
| [UFW](blocks/ufw.md) | Manages UFW firewall rules (Linux) |
| [Unarchive](blocks/unarchive.md) | Extracts archives (tar, zip, gz, bz2, xz) |
| [URI](blocks/uri.md) | Makes HTTP/HTTPS requests |
| [User](blocks/user-module.md) | Manages system user accounts |
| [Validate](blocks/validate.md) | Validates file contents and formats |
| [WaitFor](blocks/wait_for.md) | Waits for a condition before continuing |

## Features

- **i3config v2 pipeline** — Full state-machine processing
- **Rollback** — All operations are reversible via lockfile
- **Lockfile** — SHA-256 checksums prevent redundant applies
- **Privilege escalation** — Sudo integration with persistent lock
- [**Built-in variables**](reference/variables.md) — `$cwd`, `$configrDirs`, and dot-notation support
- [**Plugin system**](guides/plugin-system.md) — Extend with custom block handlers (Dart + Lua)
- **Watch mode** — Auto-apply on file changes
- [**Terminal UI**](guides/terminal-ui.md) — Task widgets, spinners, styled output, interactive prompts
- [**Secrets management**](guides/secrets.md) — Provider-agnostic secret resolution (env, file, dotenv, cmd, 1Password, keyring) with automatic redaction
- [**Remote execution**](guides/remote-execution.md) — SSH transport with CLI flags or inline `connection { }` block
- [**Multi-host**](guides/multi-host.md) — Inventory, execution strategies, per-host lockfiles, remote rollback

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
