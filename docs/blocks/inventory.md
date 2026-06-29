# Inventory and Host Blocks

The `inventory` block defines remote hosts for multi-host execution. Each
nested `host "<name>" { ... }` entry becomes a host target that strategies can
resolve by host name, role, group, or default target.

```i3
inventory {
  default_targets = ["web-01", "db-01"]

  host "web-01" {
    address = "10.0.0.11"
    port = "22"
    username = "root"
    privateKey = "/home/me/.configr/keys/web-01"
    roles = ["web"]
    groups = ["production"]
  }

  host "db-01" {
    address = "10.0.0.21"
    username = "root"
    roles = "db"
    groups = "production,primary"
  }
}
```

## Inventory Properties

| Property | Default | Description |
|----------|---------|-------------|
| `default_targets` | unset | Host names used when no target is passed |

## Host Properties

| Property | Default | Description |
|----------|---------|-------------|
| `address` | `""` | SSH address for the host |
| `port` | `22` | SSH port. String values are accepted |
| `username` | `root` | SSH username |
| `privateKey` | unset | Private key content or a local path to a key file |
| `roles` | `[]` | Role names as a list or comma-separated string |
| `groups` | `[]` | Group names as a list or comma-separated string |

If `privateKey` points at an existing local file, Configr reads the file and
stores the key content in the host model. This keeps the multi-host SSH path
compatible with host-side execution while avoiding remote binary copies.

## Targeting

Multi-host commands can resolve targets from:

| Target kind | Source |
|-------------|--------|
| Host name | `host "web-01" { ... }` |
| Role | `roles = ["web"]` |
| Group | `groups = ["production"]` |
| Default targets | `default_targets = [...]` |

See the [multi-host guide](../guides/multi-host.md) for execution strategies,
host lockfiles, and rollback behavior.

