# Pacman Package Manager Example

This example demonstrates package management using the **pacman** block on Arch Linux.

## Prerequisites

- Arch Linux system
- sudo privileges

## Running the Example

```bash
configr apply -n --dry-run        # preview
configr apply -n                   # execute
```

## Pacman Block Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `source` | string | `""` | Space-separated list of package names |
| `operation` | string | `"install"` | install, uninstall, upgrade, reinstall |
| `update_cache` | bool | `true` | Run `pacman -Sy` before operations |
| `skip_if_installed` | bool | `true` | Skip packages already present |
| `force` | bool | `false` | Force operation |

## See Also

- [Pamac](pamac/) — Manjaro's wrapper around pacman
