# Configr Documentation

Configr is a powerful configuration management tool for dotfiles and system
configuration. It uses the i3config-format for declarative, block-based
configuration files.

## Quick Links

- [CLI Usage Guide](cli-usage.md) — Command reference and examples
- [Migration Guide](migration-guide.md) — Upgrading from v1 to v2
- [Tutorial](tutorial.md) — Getting started guide
- [Architecture](architecture.md) — Core abstractions and design decisions
- [Secrets Management](secrets.md) — Provider-agnostic secret resolution
- [Remote Execution](remote-execution.md) — SSH transport for remote machines
- [Multi-Host Execution](multi-host.md) — Inventory, strategies, per-host lockfiles, remote rollback
- [SSH VM Integration Guide](ssh-vm-guide.md) — Launch Docker VMs and apply configs over SSH

## Action Blocks

Configr v2 uses **action blocks** — i3config-format blocks that each perform
a specific operation. All blocks support `source`, `destination`, and
block-specific properties.

| Block | Description |
|-------|-------------|
| [Alternatives](modules/alternatives-module.md) | Manages command alternatives (`update-alternatives`) |
| [Assert](modules/assert-module.md) | Validates conditions via shell commands |
| [AuthorizedKey](authorized_key.md) | Manages SSH authorized_keys entries |
| [Backup](backup.md) | Creates backup copies before modifications |
| [BlockInFile](modules/blockinfile-module.md) | Manages multi-line blocks in files |
| [Compress](compress.md) | Compresses files/directories into archives |
| [Copy](copy.md) | Copies files/directories to new locations |
| [Cron](cron.md) | Manages cron job entries |
| [Debug](debug.md) | Prints debug messages to the console |
| [Decompress](decompress.md) | Extracts files from archives |
| [Delete](delete.md) | Safely deletes files and directories |
| [Download](download.md) | Downloads files from remote URLs |
| [Echo](echo.md) | Prints messages to the console |
| [Execute](execute.md) | Executes shell commands |
| [Fail](fail.md) | Fails execution with a custom error message |
| [Fetch](fetch.md) | Fetches files from the target to the local machine |
| [File](file.md) | Creates/edits files with content |
| [Firewalld](firewalld.md) | Manages firewalld services, ports, and rules (Linux) |
| [GatherFacts](gather_facts.md) | Collects system facts into context variables |
| [Git](git.md) | Git repository operations |
| [Group](modules/group-module.md) | Manages system groups |
| [Hostname](modules/hostname-module.md) | Sets the system hostname |
| [KnownHosts](known_hosts.md) | Manages SSH known_hosts entries |
| [LineInFile](modules/lineinfile-module.md) | Ensures a specific line in a file |
| [LocaleGen](modules/locale_gen-module.md) | Generates system locales |
| [Mount](mount.md) | Manages mount points and fstab entries |
| [Move](move.md) | Moves/renames files and directories |
| [Network](network.md) | Network connectivity testing |
| [Package](package.md) | Package management (apt, brew, dnf, docker, flatpak, npm, pacman, pamac, pip, snap, yum) |
| [Pause](pause.md) | Pauses execution for a specified duration |
| [Permissions](permissions.md) | Sets file permissions and ownership |
| [Raw](raw.md) | Executes raw shell commands |
| [Rename](rename.md) | Renames files and directories |
| [Replace](modules/replace-module.md) | Replaces text using regular expressions |
| [Script](script.md) | Copies and executes local scripts on the target |
| [Service](service.md) | Manages system services across init systems |
| [SetFact](set_fact.md) | Sets key/value pairs as context variables |
| [Slurp](slurp.md) | Reads files and base64-encodes their content |
| [Stat](stat.md) | Retrieves file/directory statistics |
| [Symlink](symlink.md) | Creates/manages symbolic links |
| [Sync](sync.md) | Bidirectional file synchronization |
| [Sysctl](modules/sysctl-module.md) | Manages kernel parameters |
| [Systemd](systemd.md) | Manages systemd services |
| [Template](template.md) | Renders template files with Liquid |
| [Timezone](modules/timezone-module.md) | Sets the system timezone |
| [Touch](touch.md) | Updates file timestamps |
| [UFW](ufw.md) | Manages UFW firewall rules (Linux) |
| [Unarchive](unarchive.md) | Extracts archives (tar, zip, gz, bz2, xz) |
| [URI](uri.md) | Makes HTTP/HTTPS requests |
| [User](modules/user-module.md) | Manages system user accounts |
| [Validate](validate.md) | Validates file contents and formats |
| [WaitFor](wait_for.md) | Waits for a condition before continuing |

## Features

- **i3config v2 pipeline** — Full state-machine processing
- **Rollback** — All operations are reversible via lockfile
- **Lockfile** — SHA-256 checksums prevent redundant applies
- **Privilege escalation** — Sudo integration with persistent lock
- [**Built-in variables**](variables.md) — `$cwd`, `$configrDirs`, and dot-notation support
- [**Plugin system**](plugin-system.md) — Extend with custom block handlers (Dart + Lua)
- **Watch mode** — Auto-apply on file changes
- [**Terminal UI**](terminal-ui.md) — Task widgets, spinners, styled output, interactive prompts
- [**Secrets management**](secrets.md) — Provider-agnostic secret resolution (env, file, dotenv, cmd, 1Password, keyring) with automatic redaction
- [**Remote execution**](remote-execution.md) — SSH transport with CLI flags or inline `connection { }` block
- [**Multi-host**](multi-host.md) — Inventory, execution strategies, per-host lockfiles, remote rollback

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
