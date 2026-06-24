# Sysctl Module

Manages kernel parameters — Ansible-style `sysctl` module.

## Overview

The Sysctl Module configures kernel parameters via `sysctl` with persistent file management. It follows the Ansible `ansible.posix.sysctl` pattern, supporting both runtime changes and persistent configuration in sysctl configuration files.

## Features

- **Runtime changes**: Set kernel parameters immediately via `sysctl -w`
- **Persistent configuration**: Write to `/etc/sysctl.conf` or custom file
- **State management**: `present` to ensure value, `absent` to remove parameter
- **Ignore errors**: Gracefully handle unknown parameters with `ignore_errors`
- **File reload**: Re-read configuration files with `sysctl -p`
- **sysctl_set**: Force setting via sysctl command regardless of file state
- **Platform-specific**: Supports Linux, FreeBSD, OpenBSD syntax differences

## Properties

### Standard Properties
- `name` (required): Kernel parameter name (e.g., `net.ipv4.ip_forward`)
- `state` (required): `present` to ensure value, `absent` to remove

### Sysctl Properties
- `value`: Value to set (required for `present`)
- `sysctl_file`: Custom sysctl configuration file path (default: `/etc/sysctl.conf`)
- `reload`: Run `sysctl -p` after file modification (default: `true`)
- `ignore_errors`: Ignore errors from sysctl commands (default: `false`)
- `sysctl_set`: Always run `sysctl -w` regardless of file state (default: `false`)

## Examples

### Set a Kernel Parameter

```configr
resource {
  type "sysctl"
  name "net.ipv4.ip_forward"
  state "present"

  actions {
    sysctl {
      value "1"
      reload "true"
    }
  }
}
```

### Remove a Parameter

```configr
resource {
  type "sysctl"
  name "net.ipv6.conf.all.disable_ipv6"
  state "absent"

  actions {
    sysctl {
      ignore_errors "true"
    }
  }
}
```

### Use Custom Configuration File

```configr
resource {
  type "sysctl"
  name "vm.swappiness"
  state "present"

  actions {
    sysctl {
      value "10"
      sysctl_file "/etc/sysctl.d/99-custom.conf"
      reload "true"
    }
  }
}
```

## Platform Support

| Platform | Implementation | Notes |
|----------|---------------|-------|
| Linux    | Full          | `sysctl -w`, `sysctl -e -n`, `sysctl -p` |
| macOS    | Stub          | Uses `sysctl` without `-w` flag (not yet implemented) |
| FreeBSD  | Full          | `sysctl` without `-w`, reload via `/etc/rc.d/sysctl` |
| OpenBSD  | Full          | `sysctl` without `-w`/`-e`/`-p`, reload via re-execution |

## Rollback

The previous value in the sysctl file is stored in the lockfile and restored on rollback. Runtime values are also reverted.
