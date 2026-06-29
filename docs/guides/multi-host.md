# Multi-Host Execution

Use multi-host execution when one config needs to apply to several SSH targets.
Hosts can be selected directly, by role, or by group.

## Inventory

Define inventory in your config:

```i3
inventory {
  defaults {
    user = "deploy"
    port = 22
    key = "~/.ssh/id_ed25519"
  }

  host "web-1" {
    hostname = "web-1.internal"
    roles "web"
    groups "production"
    priority = 10
  }

  host "web-2" {
    hostname = "web-2.internal"
    roles "web"
    groups "production"
    priority = 20
  }

  host "db-1" {
    hostname = "db-1.internal"
    roles "db"
    groups "production"
    priority = 5
  }
}
```

## Host Properties

| Property | Description |
|----------|-------------|
| `hostname` | DNS name or IP address used for SSH |
| `user` | SSH username |
| `port` | SSH port |
| `password` | SSH password |
| `key` | SSH private key path |
| `key_passphrase` | Private key passphrase |
| `roles` | Role names used for selection |
| `groups` | Group names used for selection |
| `priority` | Ordering value for serial boot groups |
| `vars` | Host-specific variables |

## Target Selection

```bash
# Target one host
configr apply --host web-1

# Target multiple hosts
configr apply --hosts web-1,web-2

# Target a role
configr apply --role web

# Target a group
configr apply --group production
```

## Execution Strategies

```bash
# One host at a time
configr apply --role web --strategy linear

# All selected hosts at once
configr apply --role web --strategy parallel

# Priority-ordered groups
configr apply --group production --strategy serial
```

Use `linear` when changes must be cautious, `parallel` when hosts are
independent, and `serial` when priority order matters.

## Remote Rollback

Rollback uses the same target selection model:

```bash
configr rollback --host web-1
configr rollback --role web --count 1
configr rollback --group production --strategy serial
```

Each host keeps its own rollback history so a partial rollback on one target
does not erase the remaining records for that host.

## Variables

Host variables can be referenced by blocks and templates. More specific values
override broader defaults:

1. CLI variables
2. Host variables
3. Role variables
4. Group variables
5. Inventory defaults
6. Global config variables

## Recommended Workflow

```bash
configr apply --role web --dry-run
configr apply --role web --strategy linear
configr status --role web
```

For production changes, start with `--dry-run`, prefer `linear` or `serial`
unless the change is known to be independent, and roll back by host or role if
only part of the fleet needs to be restored.
