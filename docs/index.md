# Configr Documentation

Configr applies declarative configuration to local machines and SSH targets.
Use it for dotfiles, system packages, services, files, templates, secrets,
hooks, and multi-host deployments with rollback.

## Start Here

- [Getting Started](getting-started/tutorial.md) - install Configr and apply a first config
- [CLI Usage](getting-started/cli-usage.md) - commands, global flags, and examples
- [Config Organization](guides/config-organization.md) - split configs with top-level `include`
- [Remote Execution](guides/remote-execution.md) - run a local config against an SSH host
- [Multi-Host Execution](guides/multi-host.md) - inventories, roles, groups, and strategies
- [Secrets Management](guides/secrets.md) - env, file, dotenv, command, 1Password, and keyring secrets
- [Rollback](reference/rollback.md) - lockfiles and restoring previous state
- [Built-In Variables](reference/variables.md) - environment and config variables available to blocks

## Configuration Model

| Topic | Use it for |
|-------|------------|
| [Connection](blocks/connection.md) | Switch execution to a remote SSH backend |
| [Inventory and Host](blocks/inventory.md) | Define hosts, roles, groups, and defaults |
| [Dynamic](blocks/dynamic.md) | Repeat child blocks for each item in a list |
| [Resources](blocks/resources.md) | Group several actions around one managed object |
| [Commands](blocks/commands.md) | Define named commands and run them with `configr run` |
| [Structural Packages](blocks/packages-structural.md) | Describe grouped package requirements |
| [Script Hooks](blocks/scripts.md) | Run pre-apply and post-apply scripts |
| [Plugin](blocks/plugin.md) | Load Lua plugin files or plugin directories |
| [Secrets](blocks/secrets.md) | Resolve and redact sensitive values |

## Action Blocks

Action blocks make changes or inspect state on the selected target.

| Block | Description |
|-------|-------------|
| [Alternatives](blocks/alternatives-module.md) | Manages command alternatives (`update-alternatives`) |
| [Assert](blocks/assert-module.md) | Validates conditions via shell commands |
| [AuthorizedKey](blocks/authorized_key.md) | Manages SSH authorized_keys entries |
| [Backup](blocks/backup.md) | Creates backup copies before modifications |
| [BlockInFile](blocks/blockinfile-module.md) | Manages multi-line blocks in files |
| [Compress](blocks/compress.md) | Compresses files/directories into archives |
| [Container](blocks/container.md) | Manages Docker containers |
| [ContainerExec](blocks/container_exec.md) | Runs commands inside Docker containers |
| [ContainerLogs](blocks/container_logs.md) | Captures Docker container logs |
| [Copy](blocks/copy.md) | Copies files/directories to new locations |
| [Cron](blocks/cron.md) | Manages cron job entries |
| [Debug](blocks/debug.md) | Prints debug messages to the console |
| [Decompress](blocks/decompress.md) | Extracts files from archives |
| [Delete](blocks/delete.md) | Safely deletes files and directories |
| [Dependency](blocks/dependency.md) | Waits for host, network, or port dependencies |
| [Download](blocks/download.md) | Downloads files from remote URLs |
| [Echo](blocks/echo.md) | Prints messages to the console |
| [Execute](blocks/execute.md) | Executes shell commands |
| [Fail](blocks/fail.md) | Fails execution with a custom error message |
| [Fetch](blocks/fetch.md) | Fetches files from the target to the local machine |
| [File](blocks/file.md) | Creates/edits files with content |
| [Firewalld](blocks/firewalld.md) | Manages firewalld services, ports, and rules |
| [GatherFacts](blocks/gather_facts.md) | Collects system facts into variables |
| [Git](blocks/git.md) | Git repository operations |
| [Group](blocks/group-module.md) | Manages system groups |
| [Hostname](blocks/hostname-module.md) | Sets the system hostname |
| [KnownHosts](blocks/known_hosts.md) | Manages SSH known_hosts entries |
| [LineInFile](blocks/lineinfile-module.md) | Ensures a specific line in a file |
| [LocaleGen](blocks/locale_gen-module.md) | Generates system locales |
| [Mount](blocks/mount.md) | Manages mount points and fstab entries |
| [Move](blocks/move.md) | Moves/renames files and directories |
| [Network](blocks/network.md) | Network connectivity testing |
| [Package](blocks/package.md) | Package management through the selected package manager |
| [Package Manager Blocks](blocks/package-managers.md) | Direct package-manager blocks such as `apt`, `brew`, `dnf`, `npm`, and `pip` |
| [Pause](blocks/pause.md) | Pauses execution for a specified duration |
| [Permissions](blocks/permissions.md) | Sets file permissions and ownership |
| [Raw](blocks/raw.md) | Executes raw shell commands |
| [Rename](blocks/rename.md) | Renames files and directories |
| [Replace](blocks/replace-module.md) | Replaces text using regular expressions |
| [Script](blocks/script.md) | Runs executable scripts on the target |
| [Service](blocks/service.md) | Manages system services across init systems |
| [SetFact](blocks/set_fact.md) | Sets key/value pairs as variables |
| [Slurp](blocks/slurp.md) | Reads files and stores base64 content |
| [Stat](blocks/stat.md) | Retrieves file/directory statistics |
| [Symlink](blocks/symlink.md) | Creates/manages symbolic links |
| [Sync](blocks/sync.md) | Synchronizes directories |
| [Sysctl](blocks/sysctl-module.md) | Manages kernel parameters |
| [Systemd](blocks/systemd.md) | Manages systemd services |
| [Template](blocks/template.md) | Renders template files with Liquid |
| [Timezone](blocks/timezone-module.md) | Sets the system timezone |
| [Touch](blocks/touch.md) | Updates file timestamps |
| [UFW](blocks/ufw.md) | Manages UFW firewall rules |
| [Unarchive](blocks/unarchive.md) | Extracts archives |
| [URI](blocks/uri.md) | Makes HTTP/HTTPS requests |
| [User](blocks/user-module.md) | Manages system user accounts |
| [Validate](blocks/validate.md) | Validates file contents and formats |
| [WaitFor](blocks/wait_for.md) | Waits for a condition before continuing |

## Common Workflows

```bash
configr init
configr apply --dry-run
configr apply
configr run verify
configr rollback --count 1
```

```bash
configr apply --host server.example.com --ssh-user deploy --ssh-key ~/.ssh/id_ed25519
```
