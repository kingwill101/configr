# APT Package Manager Example

This example demonstrates package management using the **apt** block on Debian/Ubuntu systems.

## Prerequisites

- Debian or Ubuntu system
- sudo privileges
- Internet connection for package downloads

## Running the Example

```bash
configr apply -n --dry-run        # preview
configr apply -n                   # execute
```

## What This Example Demonstrates

- **Development tools** — git, curl, wget, vim, nano, htop, tree, build-essential
- **Web server stack** — nginx, php-fpm, mysql-server, redis-server
- **Security tools** — fail2ban, ufw, clamav, rkhunter, unattended-upgrades
- **System utilities** — htop, iotop, ncdu, rsync, zip, unzip, jq, yq

## Apt Block Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `source` | string | `""` | Space-separated list of package names |
| `operation` | string | `"install"` | install, uninstall, upgrade, reinstall |
| `update_cache` | bool | `true` | Run `apt update` before operations |
| `skip_if_installed` | bool | `true` | Skip packages already present |
| `repositories` | list | `[]` | Additional APT repositories to add |
| `force` | bool | `false` | Force operation even on errors |

## Cleanup

```bash
sudo apt remove git curl wget vim nano htop tree build-essential
sudo apt remove nginx php-fpm mysql-server redis-server
sudo apt remove fail2ban ufw clamav rkhunter unattended-upgrades
sudo apt remove htop iotop ncdu rsync zip unzip jq yq
```
