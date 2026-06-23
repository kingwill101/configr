# Built-in Variables

Configr exposes variables in the config processor's context. You reference
them with `$name` syntax anywhere a value is expected. i3config supports
**dot-notation** for nested access — e.g. `$configrDirs.cacheDir`.

## Quick Reference

| Variable | Type | Description |
|----------|------|-------------|
| `$cwd` | `String` | Absolute path to the directory containing the config file |
| `$configrDirs` | `ConfigrDirectories` | Object with `.cacheDir`, `.backupDir`, `.projectConfigrPath` (dot-notation) |
| `$configrCacheDir` | `String` | Shortcut for `$configrDirs.cacheDir` |
| `$configrBackupDir` | `String` | Shortcut for `$configrDirs.backupDir` |
| `$name` | `String` | Auto-set inside `command { ... }` to the sub-command name |
| `$template_str` | `String` | Set inside template blocks for the raw template string |

User-defined variables set via `set name = value` are also supported.

## `$cwd`

The directory where the config file lives — useful for resolving relative paths
in `source`, `destination`, and other file-related properties.

```i3
copy {
  source = "$cwd/configs/bashrc"
  destination = "~/.bashrc"
}

execute {
  command = "ls $cwd"
}

symlink {
  source = "$cwd/dotfiles/gitconfig"
  destination = "~/.gitconfig"
}
```

## `$configrDirs` (dot-notation)

A structured object. Use dot-notation to access its fields:

| Field | Type | Description |
|-------|------|-------------|
| `$configrDirs.cacheDir` | `String` | Configr cache directory |
| `$configrDirs.backupDir` | `String` | Configr backup directory |
| `$configrDirs.projectConfigrPath` | `String` | `.configr/` directory alongside the config |

```i3
# Equivalent shortcuts
echo { message = "$configrDirs.cacheDir" }
echo { message = "$configrCacheDir" }
```

## `set` — User-defined Variables

Define your own variables with the `set` command:

```i3
set my_home = "/home/user"

copy {
  source = "$my_home/dotfiles/bashrc"
  destination = "$my_home/.bashrc"
}
```

## Dot-notation Example

Combine dot-notation with `echo` to inspect all built-in variables:

```i3
echo { message = "Config directory: $cwd" }
echo { message = "Cache dir: $configrDirs.cacheDir" }
echo { message = "Backup dir: $configrDirs.backupDir" }
```

## ConfigrDirectories API

When stored in a context option like `$_configrDirs`, the full
`ConfigrDirectories` object has these properties accessible via
dot-notation:

- `projectConfigrPath` — `.configr/` directory next to the config file
- `cacheDir` — cache directory (default `~/.cache/configr` or project-local)
- `backupDir` — backup directory (default `~/.config/configr/backups` or project-local)
- `ensureAll()` — creates directories if missing (not usable in config syntax)
