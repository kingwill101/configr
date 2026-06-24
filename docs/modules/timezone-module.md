# Timezone Module

Sets the system timezone — Ansible-style `timezone` module.

## Overview

The Timezone Module configures the system timezone with support for multiple operating systems. On Linux it uses `timedatectl` with a fallback to `/etc/localtime` symlink management; on macOS it uses `systemsetup`.

## Features

- **Timezone validation**: Validates against `/usr/share/zoneinfo/`
- **Multiple strategies**: `timedatectl` on Linux, `systemsetup` on macOS
- **Atomic changes**: Uses symlink atomic replacement
- **Rollback**: Previous timezone is restored

## Properties

### Standard Properties
- `name` (required): Timezone name (e.g., `America/New_York`, `Europe/London`, `UTC`)

## Examples

### Set Timezone

```configr
resource {
  type "timezone"
  name "America/New_York"
  state "present"

  actions {
    timezone {}
  }
}
```

### Set UTC

```configr
resource {
  type "timezone"
  name "UTC"
  state "present"

  actions {
    timezone {}
  }
}
```

## Platform Support

| Platform | Implementation | Commands Used |
|----------|---------------|---------------|
| Linux    | Full          | `timedatectl set-timezone`, `/etc/localtime` symlink |
| macOS    | Full          | `systemsetup -settimezone` |
| FreeBSD  | Stub          | Not yet implemented (will use `/etc/localtime` symlink + `/etc/rc.conf`) |

## Validation

Before setting the timezone, the module validates it against `/usr/share/zoneinfo/`. If the timezone is not found, execution fails with a clear error message.

## Rollback

The previous timezone is stored in the lockfile and restored on rollback.
