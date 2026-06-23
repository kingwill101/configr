# Snap Package Manager Example

This example demonstrates package management using the **snap** block on Ubuntu or other snap-enabled Linux distributions.

## Prerequisites

- snapd service installed and running
- sudo privileges

## Running the Example

```bash
configr apply -n --dry-run        # preview
configr apply -n                   # execute
```

## Snap Block Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `source` | string | `""` | Space-separated list of snap names |
| `operation` | string | `"install"` | install, uninstall, upgrade |
| `skip_if_installed` | bool | `true` | Skip snaps already present |
| `force` | bool | `false` | Force operation |

## Cleanup

```bash
sudo snap remove firefox vlc gimp krita
```
