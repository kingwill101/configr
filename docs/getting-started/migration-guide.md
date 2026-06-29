# Legacy Migration Guide

## Overview

Configr now uses the current block syntax by default. The `resource` grouping
model is still supported; the migration is about assignment syntax and runtime
behavior, not about removing resources.

## Key Changes

### 1. Config Syntax

Current configs use i3config-format blocks with `=` for property assignment.

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

**Current top-level action style:**
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

**Current resource-scoped style:**
```i3
resource {
  source = "myfile.txt"
  destination = "~/config/myfile.txt"

  actions {
    copy {}
    permissions {
      mode = 644
    }
  }
}
```

Both styles are supported. Prefer top-level action blocks for small, direct
configs. Prefer `resource` when the operations represent one managed object,
need shared context, or should emit resource-level events.

### 2. CLI Usage

The current pipeline is the default. Run commands directly:

```bash
configr apply
configr rollback
```

### 3. Config File Location

Configr looks for a `config` file in the current directory. The current
lockfile format uses `config.lock.json`.

### 4. Runtime Changes

| Area | Legacy | Current |
|------|--------|---------|
| CLI opt-in | Required a legacy/current mode flag | Current mode is always used |
| Assignment syntax | Often allowed bare values | Prefer `key = "value"` |
| Lockfile | Legacy lockfile format | Current `config.lock.json` format |
| Remote execution | Limited local-first behavior | Local config can target SSH hosts |
| Resource grouping | Supported | Still supported |

### 5. Compatibility

- The legacy opt-in flag has been removed.
- Legacy lockfiles are not read by the current pipeline.
- `resource { }` remains supported.

### 6. Block Types

The current pipeline supports top-level action blocks, resource-scoped action blocks,
configuration blocks such as `connection`, `inventory`, `dynamic`, and
`secrets`, and direct package-manager blocks such as `apt`, `brew`, `dnf`,
`npm`, `pip`, and `yum`.

See the [block reference](../blocks/resources.md) and the documentation sidebar
for the current supported block list.

### 7. Plugin Migration

Use Lua plugins from a `plugin { }` block or pass plugin directories with
`--plugin-dir`. See the [plugin guide](../guides/plugin-system.md).
