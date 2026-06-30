# Built-in Variables

Configr exposes system facts as variables in the config processor's context.
Reference them with `$name` syntax. **Flat underscore names** work in all
positions (quoted strings, bare values, assignments):

```i3
echo { message = "OS: $os_name, user: $user_username" }
```

Dotted names (e.g. `$os.name`) are also set but only resolve inside
`expandVariables` paths — prefer flat names for guaranteed behaviour.

## Quick Reference

### OS Facts

| Variable | Example | Description |
|----------|---------|-------------|
| `$os_name` | `linux` | `Platform.operatingSystem` |
| `$os_version` | `5.15.0-91-generic` | `Platform.operatingSystemVersion` |
| `$os_architecture` | `x86_64` / `aarch64` | `uname -m` |
| `$os_kernel` | `5.15.0` | Major kernel version |
| `$os_distribution` | `ubuntu` / `debian` | `ID` from `/etc/os-release` |
| `$os_distribution_version` | `22.04` | `VERSION_ID` from `/etc/os-release` |
| `$os_family` | `debian` / `redhat` / `darwin` | `ID_LIKE` from `/etc/os-release` or inferred |

### Host Facts

| Variable | Example | Description |
|----------|---------|-------------|
| `$host_hostname` | `my-machine` | `Platform.localHostname` |
| `$host_fqdn` | `my-machine.local` | `hostname -f` |

### User Facts

| Variable | Example | Description |
|----------|---------|-------------|
| `$user_username` | `alice` | `$USER` / `$USERNAME` |
| `$user_home` | `/home/alice` | `$HOME` |
| `$user_shell` | `/bin/zsh` | `$SHELL` |

### Date / Time

| Variable | Example | Description |
|----------|---------|-------------|
| `$date_year` | `2026` | 4-digit year |
| `$date_month` | `06` | Zero-padded month |
| `$date_day` | `23` | Zero-padded day |
| `$date_hour` | `14` | Zero-padded hour (24h) |
| `$date_minute` | `05` | Zero-padded minute |
| `$date_second` | `09` | Zero-padded second |
| `$date_timestamp` | `2026-06-23T14:05:09.000` | ISO 8601 |
| `$date_epoch` | `1760745909` | Unix epoch seconds |

### Configr Info

| Variable | Example | Description |
|----------|---------|-------------|
| `$configr_version` | `1.0.0` | Current Configr version |
| `$configr_cache_dir` | `/home/alice/.cache/configr` | Cache directory |
| `$configr_backup_dir` | `/home/alice/.cache/configr/backups` | Backup directory |

### Environment Variables (Common)

| Variable | Example | Description |
|----------|---------|-------------|
| `$env_HOME` | `/home/alice` | Home directory |
| `$env_USER` | `alice` | Current user |
| `$env_SHELL` | `/bin/zsh` | Login shell |
| `$env_PATH` | `/usr/bin:/bin` | System PATH |
| `$env_EDITOR` | `vim` | Default editor |
| `$env_TERM` | `xterm-256color` | Terminal type |
| `$env_LANG` | `en_US.UTF-8` | Locale |
| `$env_XDG_CONFIG_HOME` | `/home/alice/.config` | XDG config home |
| `$env_XDG_DATA_HOME` | `/home/alice/.local/share` | XDG data home |
| `$env_XDG_CACHE_HOME` | `/home/alice/.cache` | XDG cache home |
| `$env_XDG_RUNTIME_DIR` | `/run/user/1000` | XDG runtime dir |
| `$env_DISPLAY` | `:0` | X11 display |
| `$env_WAYLAND_DISPLAY` | `wayland-0` | Wayland display |
| `$env_XDG_CURRENT_DESKTOP` | `GNOME` | Desktop environment |

### Shortcuts

| Variable | Description |
|----------|-------------|
| `$cwd` | Directory of the config file (for relative paths) |
| `$configrCacheDir` | Shortcut for `$configr_cache_dir` |
| `$configrBackupDir` | Shortcut for `$configr_backup_dir` |
| `$name` | Auto-set inside `command { ... }` |
| `$template_str` | Set inside template blocks |

## Variable Naming Caveat

The i3config grammar includes `-` in variable names, so `$os_family-debian`
would be parsed as a single reference `os_family-debian` instead of `$os_family`
followed by the literal string `-debian`. Always separate adjacent variables
and hyphens with a non-word character (space, `/`, `.`, `:`, etc.):

```i3
# Correct — separate with spaces
set path = "$date_year / $date_month / $date_day"

# If you need hyphens, use string concatenation via separate echo args or
# put the hyphen in a distinct position that isn't word-adjacent.
echo "$date_year-" "$date_month-" "$date_day"
```

This is a grammar limitation — underscore `_` in names is unaffected.

## Usage Examples

```i3
# Platform-aware package management — use $os_family to pick the right manager
packages {
  package {
    name = "firefox"
    manager = "$os_family" == "debian" ? "apt" : "dnf"
  }
}

# Timestamped backups (use dot separator instead of hyphen)
backup {
  source = "$user_home/.bashrc"
  destination = "$configr_backup_dir/bashrc.$date_timestamp"
}

# Platform-specific downloads
download {
  url = "https://github.com/user/repo/releases/latest/download/\
         binary-$os_architecture"
  destination = "$user_home/.local/bin/my-tool"
}

# Use environment variables for paths
copy {
  source = "$cwd/ssh-config"
  destination = "$env_HOME/.ssh/config"
}

# Date-based naming (use dots instead of hyphens)
symlink {
  source = "$cwd/configs/bashrc"
  destination = "$configr_backup_dir/bashrc.$date_year.$date_month.$date_day"
}
```

## Reference in `set`

```i3
set backup_path = "$configr_backup_dir / $date_year"
```

## ConfigrDirectories API

When stored in a context option like `$_configrDirs`, the full
`ConfigrDirectories` object has these properties accessible via
dot-notation (Lua plugins only):

- `projectConfigrPath` — `.configr/` directory next to the config file
- `cacheDir` — cache directory
- `backupDir` — backup directory
- `ensureAll()` — creates directories if missing
