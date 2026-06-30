# DNF Package Manager Example

This example demonstrates package management using the **dnf** block on Fedora or RHEL 8+.

## Prerequisites

- Fedora or RHEL 8+ system
- sudo privileges

## Running the Example

```bash
configr apply -n --dry-run        # preview
configr apply -n                   # execute
```

## DNF Block Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `source` | string | `""` | Space-separated list of package names |
| `operation` | string | `"install"` | install, uninstall, upgrade, reinstall |
| `update_cache` | bool | `true` | Run `dnf check-update` before operations |
| `skip_if_installed` | bool | `true` | Skip packages already present |
| `force` | bool | `false` | Force operation |

## Cleanup

```bash
sudo dnf remove git curl wget vim nano htop tree gcc make
sudo dnf remove nginx php-fpm mariadb-server redis
sudo dnf remove fail2ban ufw clamav rkhunter
sudo dnf remove htop iotop ncdu rsync zip unzip jq yq
```
