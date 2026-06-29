# How Configr Applies Changes

Configr has one main rule: the config stays where you run the CLI, while the
target can be either the local machine or an SSH host.

## Local Apply

```mermaid
flowchart LR
    Config[config file] --> CLI[configr apply]
    CLI --> Target[local machine]
    Target --> Lockfile[config.lock.json]
```

Use this for dotfiles, workstation bootstrap, and local server setup.

```bash
configr apply --dry-run
configr apply
```

## Remote Apply

```mermaid
flowchart LR
    Config[local config file] --> CLI[configr apply --host]
    CLI --> SSH[SSH/SFTP connection]
    SSH --> Remote[remote host files and processes]
    Remote --> Lockfile[per-host lockfile]
```

Use this when your control machine should keep the config, hooks, and plugins,
but file and process operations must happen on another host.

```bash
configr apply \
  --host server.example.com \
  --ssh-user deploy \
  --ssh-key ~/.ssh/id_ed25519
```

## Multi-Host Apply

Inventories let one config target several hosts by name, role, or group. The
same blocks can run serially, in priority groups, or in parallel depending on
the selected strategy.

```i3
inventory {
  host "web-1" {
    hostname = "web-1.internal"
    user = "deploy"
  }

  role "web" {
    hosts "web-1"
  }
}
```

## Rollback

Successful applies write lockfiles. Rollback reads those records in reverse
order and restores the previous state for the selected local or remote target.

```bash
configr rollback
configr rollback --count 1
```

## Safety Boundaries

- `--dry-run` previews changes without applying them.
- Lockfiles are written only after successful work is recorded.
- Remote applies route file and process operations over SSH/SFTP.
- Secrets are redacted from normal output and event logs.
