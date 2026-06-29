# Variables Reference

Configr exposes system facts as variables in the config processor's context.
Reference them with `$name` syntax. **Flat underscore names** work in all
positions (quoted strings, bare values, assignments):

```i3
echo { message = "OS: $os_name, user: $user_username" }
```

Dotted names, such as `$os.name`, are also set for most built-ins but only
resolve in paths that call `expandVariables`. Prefer flat names for normal
config files.

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

### Environment Variables

Configr exposes a fixed set of common process environment variables as
`$env_<NAME>` and `env.<NAME>`. It does **not** automatically materialize every
environment variable into config syntax.

For arbitrary environment lookups:

- Lua plugins/hooks can call `getEnv("NAME")`.
- Secrets can use the env provider.
- Shell commands can read their inherited process environment directly.

| Variable | Example | Description |
|----------|---------|-------------|
| `$env_HOME` | `/home/alice` | Home directory |
| `$env_USER` | `alice` | Current user |
| `$env_USERNAME` | `alice` | Windows-style current user name |
| `$env_SHELL` | `/bin/zsh` | Login shell |
| `$env_PATH` | `/usr/bin:/bin` | System PATH |
| `$env_PWD` | `/home/alice/project` | Current process directory |
| `$env_EDITOR` | `vim` | Default editor |
| `$env_VISUAL` | `code` | Visual editor |
| `$env_TERM` | `xterm-256color` | Terminal type |
| `$env_LANG` | `en_US.UTF-8` | Locale |
| `$env_XDG_CONFIG_HOME` | `/home/alice/.config` | XDG config home |
| `$env_XDG_DATA_HOME` | `/home/alice/.local/share` | XDG data home |
| `$env_XDG_CACHE_HOME` | `/home/alice/.cache` | XDG cache home |
| `$env_XDG_RUNTIME_DIR` | `/run/user/1000` | XDG runtime dir |
| `$env_DBUS_SESSION_BUS_ADDRESS` | `unix:path=/run/user/1000/bus` | D-Bus session bus |
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

## Variable Sources and Precedence

Configr uses an Ansible-style precedence middleware for variables that can be
provided from outside the normal config context. Higher layers override lower
layers:

| Priority | Layer | Source |
|----------|-------|--------|
| 5 | CLI vars | `--var key=value` and host-specific vars passed by multi-host apply |
| 4 | Host vars | Inventory host variables |
| 3 | Group vars | Inventory group variables |
| 2 | Secrets | Values resolved by `secrets { ... }` |
| 1 | Facts | Values gathered by `gather_facts { ... }` |

Variables assigned directly in the config, and variables set by `set_fact`,
live in the normal i3config context. They are checked after the precedence
middleware layers.

## Dynamic Variables From Blocks

Some blocks set variables as a side effect of execution:

| Block | Variables |
|-------|-----------|
| `set_fact` | Whatever keys the block assigns |
| `secrets` | Resolved secret names |
| `gather_facts` | `os_family`, `distribution`, `distribution_version`, `architecture`, `system`, `hostname`, and best-effort values such as `kernel`, `kernel_version`, `processor_count`, `memtotal_mb`, `mounts`, `interfaces` |
| `stat` | `stat_exists`, `stat_islnk`, `stat_isdir`, `stat_isreg`, `stat_type`, `stat_mode`, `stat_size`, and timestamp/checksum fields when available |
| `slurp` | `slurp_content`, `slurp_encoding`, `slurp_size` |
| `uri` | `uri_status`, `uri_content`, `uri_method`, `uri_url` |
| `unarchive` | `unarchive_files` |
| `template` | `_rendered_content` internally |

## Multi-Host Variables

Multi-host inventory can add variables from groups and hosts. During host
execution, group variables are layered below host variables, and both are
available to the local apply pipeline that targets the SSH remote.

Host facts can also be loaded through `hostvars` from `.configr/facts/*.json`
when gathered facts are persisted per host. The `hostvars` map is intended for
cross-host lookups in multi-host templates and orchestration logic.

## Lua Context and Environment APIs

Lua plugins and hooks receive the Configr built-ins through the same context
plus helper APIs:

| Function | Purpose |
|----------|---------|
| `getEnv(name)` | Read an arbitrary process environment variable |
| `getVariable(name)` | Read a Configr context variable |
| `setVariable(name, value)` | Set a Configr context variable |
| `expandVariables(str)` | Expand Configr variable references in a string |
| `getContext(key)` | Read static Lua plugin context, such as `platform` or `hostname` |
| `configrCacheDir()` | Return the active cache directory |
| `configrBackupDir()` | Return the active backup directory |

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
