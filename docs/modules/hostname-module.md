# Hostname Module

Sets the system hostname.

## Overview

The Hostname Module manages the system's hostname, separating **current** (transient/runtime) from **permanent** (persistent across reboot) hostnames. It supports multiple strategies via the `use` parameter.

## Features

- **Dual hostname management**: Sets both current and permanent hostname
- **Strategy selection**: Auto-detect or force a specific strategy via `use`
- **Multiple Linux strategies**: `systemd`, `hostname`, `file`, `generic`
- **macOS support**: Uses `scutil` and `/Library/Preferences/SystemConfiguration/preferences.plist`
- **FreeBSD support**: Uses `hostname` command and `/etc/rc.conf`

## Properties

### Standard Properties
- `name` (required): The hostname to set

### Hostname Properties
- `use`: Strategy to use (`systemd`, `hostname`, `file`, `generic`). Auto-detected if omitted.

### Strategy Details

| Strategy | Description | Commands Used |
|----------|-------------|---------------|
| `systemd` | systemd-hostnamed | `hostnamectl set-hostname` |
| `hostname` | Traditional hostname command | `hostname` + `/etc/hostname` |
| `file` | Direct /etc/hostname write | File write + `hostname` |
| `generic` | Multi-step fallback | `hostname` + `/etc/hostname` + `/etc/sysconfig/network` |

If `use` is not specified, the strategy is auto-detected:
1. Check if `systemd-hostnamed` is running → use `systemd`
2. Check if `/etc/hostname` exists → use `file`
3. Fall back to `generic`

## Examples

### Set Hostname (Auto-detect)

```configr
resource {
  type "hostname"
  name "webserver01"
  state "present"

  actions {
    hostname {}
  }
}
```

### Set Hostname with Specific Strategy

```configr
resource {
  type "hostname"
  name "appserver01"
  state "present"

  actions {
    hostname {
      use "systemd"
    }
  }
}
```

## Platform Support

| Platform | Implementation | Methods |
|----------|---------------|---------|
| Linux    | Full          | `hostnamectl`, `hostname` command, file write |
| macOS    | Full          | `scutil --set HostName`, `scutil --set ComputerName`, `scutil --set LocalHostName` |
| FreeBSD  | Full          | `hostname` command, `/etc/rc.conf` update |

## Rollback

The previous hostname is stored in the lockfile and restored on rollback. Both current and permanent hostnames are restored.
