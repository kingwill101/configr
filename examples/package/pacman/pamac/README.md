# Pamac Package Manager Example

This example demonstrates package management using the **pamac** block on Manjaro Linux.

## Prerequisites

- Manjaro Linux system
- sudo privileges

## Running the Example

```bash
configr apply -n --dry-run        # preview
configr apply -n                   # execute
```

## What This Example Demonstrates

- **AUR support** — Pamac has built-in AUR support for installing from the Arch User Repository
- **Standard packages** — All regular pacman-compatible packages

## Pamac Block Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `source` | string | `""` | Space-separated list of package names |
| `operation` | string | `"install"` | install, uninstall, upgrade, reinstall |
| `update_cache` | bool | `true` | Update cache before operations |
| `skip_if_installed` | bool | `true` | Skip packages already present |
| `force` | bool | `false` | Force operation |

## Note

Pamac handles AUR packages transparently — just include the AUR package name in `source` and Pamac will build and install it automatically.
