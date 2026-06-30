# YUM Package Manager Example

This example demonstrates package management using the **yum** block on RHEL/CentOS 7.

## Prerequisites

- RHEL or CentOS 7 system
- sudo privileges

## Running the Example

```bash
configr apply -n --dry-run        # preview
configr apply -n                   # execute
```

## YUM Block Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `source` | string | `""` | Space-separated list of package names |
| `operation` | string | `"install"` | install, uninstall, upgrade, reinstall |
| `update_cache` | bool | `true` | Run `yum makecache` before operations |
| `skip_if_installed` | bool | `true` | Skip packages already present |
| `force` | bool | `false` | Force operation |

## Note

YUM is the legacy package manager for RHEL 7 and earlier. For RHEL 8+, use DNF instead.

## Cleanup

```bash
sudo yum remove git curl wget vim nano htop tree gcc make
sudo yum remove nginx php-fpm mariadb-server redis
sudo yum remove fail2ban policycoreutils clamav
sudo yum remove htop iotop ncdu rsync zip unzip jq
```
