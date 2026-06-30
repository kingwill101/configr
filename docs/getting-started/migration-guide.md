# Migration Guide: v1 to v2

## Overview

Configr v2 replaces the old manual-parsing pipeline with the i3config v2
state-machine processor. Action blocks are now `BlockHandler` subclasses
that execute during config processing — no more separate collector pattern.

## Key Changes

### 1. Config Syntax

v2 uses i3config-format blocks with `=` for property assignment.

**v1 (old):**
```i3
resource {
  source "myfile.txt"
  destination "~/config/myfile.txt"
  actions {
    copy {}
    permissions {
      mode "644"
    }
  }
}
```

**v2 (new):**
```i3
copy {
  source = "myfile.txt"
  destination = "~/config/myfile.txt"
}

permissions {
  source = "myfile.txt"
  destination = "~/config/myfile.txt"
  mode = 644
}
```

### 2. CLI Usage

All commands now require the `--v2` flag to use the new pipeline:

```bash
configr apply --v2
configr rollback --v2
```

### 3. Config File Location

Configr v2 looks for a `config` file in the current directory. No more
`.json` lockfiles in the old format — v2 uses `config.lock.json`.

### 4. What Changed Internally

| Area | v1 | v2 |
|------|----|----|
| Parser | Custom i3 traversal | `i3config` v2 parser + processor |
| Action model | `Action` + `ResourceModule` classes | `ActionBlock` subclass per operation |
| Execution | `ConfigManager.applyConfig()` | `ConfigrRuntime.apply()` |
| Lockfile | `LockfileManager` | `V2LockfileManager` |
| CLI framework | Legacy `print` | Artisanal (`io.title()`, etc.) |
| Privilege lock | Singleton `PrivilegeLock.instance` | Instance-based with timeout |

### 5. Backward Compatibility

- v1 config files still work without `--v2`
- The `--v2` flag is opt-in
- v1 lockfiles are not read by the v2 pipeline
- `group { }`, `before`/`after` hooks, and named action blocks are v1-only

### 6. Block Types

All 21 action blocks are supported in v2:

backup, compress, copy, decompress, delete, download, echo, execute,
file, git, move, network, package, permissions, rename, symlink, sync,
systemd, template, touch, validate

### 7. Plugin Migration

v2 plugins register as `ActionBlock` subclasses through the handler
registration API. See `--plugin-dir` flag for custom plugin directories.
