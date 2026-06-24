# Group Module

Manages system groups — Ansible-style `group` module.

## Overview

The Group Module creates, modifies, and removes system groups with full rollback support. It automatically detects the operating system and uses the appropriate platform-specific commands.

## Features

- **Group Creation**: Create system or regular groups with optional GID
- **Group Deletion**: Remove existing groups
- **ID Management**: Specify or auto-assign group IDs
- **Local Groups**: macOS local group support
- **Rollback**: Full undo support

## Properties

### Standard Properties
- `name` (required): Group name to manage
- `state` (required): `present` to create, `absent` to remove

### Group Properties
- `gid`: Group ID (numeric, auto-assigned if omitted)

### Boolean Properties
- `system`: Create as system group
- `local`: Use local group on macOS (`dseditgroup -o local`)
- `force`: Force removal even if group is a primary group

## Examples

### Create a Group

```configr
resource {
  type "group"
  name "developers"
  state "present"

  actions {
    group {
      gid "1500"
    }
  }
}
```

### Create a System Group

```configr
resource {
  type "group"
  name "webserver"
  state "present"

  actions {
    group {
      system "true"
    }
  }
}
```

### Remove a Group

```configr
resource {
  type "group"
  name "oldgroup"
  state "absent"

  actions {
    group {
      force "true"
    }
  }
}
```

## Platform Support

| Platform | Implementation | Commands Used |
|----------|---------------|---------------|
| Linux    | Full          | `groupadd`, `groupdel`, `groupmod`, `getent` |
| macOS    | Stub          | Not yet implemented (will use `dseditgroup`) |
| FreeBSD  | Stub          | Not yet implemented (will use `pw`) |

## Rollback

Created groups are tracked in the lockfile and removed on rollback. Deleted groups are recreated with their original GID.
