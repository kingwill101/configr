# Assert Module

Validates conditions during configuration — Ansible-style `assert`.

## Overview

The Assert Module evaluates a shell command as a condition and fails the configuration run if it does not succeed. It is used to validate prerequisites, check system state, and ensure conditions are met before proceeding with subsequent operations.

## Features

- **Shell condition testing**: Run arbitrary commands to validate state
- **Custom failure messages**: Provide human-readable error messages
- **Custom success messages**: Confirm successful validation
- **No side effects**: Read-only — never modifies system state
- **No rollback needed**: Assert has nothing to undo

## Properties

### Standard Properties
- `condition` (required): Shell command to test. The command must exit with code `0` for success.

### Assert Properties
- `fail_msg`: Message to display on failure (default: `Assertion failed`)
- `success_msg`: Message to display on success (default: `Assertion passed`)

## Examples

### Check if a Command Exists

```configr
resource {
  type "assert"
  state "present"

  actions {
    assert {
      condition "which docker"
      fail_msg "Docker is not installed"
      success_msg "Docker is available"
    }
  }
}
```

### Check File Contents

```configr
resource {
  type "assert"
  state "present"

  actions {
    assert {
      condition "grep -q 'feature_enabled=true' /etc/myapp/config"
      fail_msg "Feature is not enabled in config"
      success_msg "Feature is enabled"
    }
  }
}
```

### Check System Requirements

```configr
resource {
  type "assert"
  state "present"

  actions {
    assert {
      condition "test $(uname -m) = 'x86_64'"
      fail_msg "This configuration requires a 64-bit system"
      success_msg "System architecture is valid"
    }
  }
}
```

### Combined Prerequisites Check

```configr
resources {
  resource {
    type "assert"
    state "present"
    actions {
      assert {
        condition "test -f /etc/debian_version"
        fail_msg "This configuration is for Debian-based systems only"
      }
    }
  }

  resource {
    type "assert"
    state "present"
    actions {
      assert {
        condition "which curl"
        fail_msg "curl is required but not installed"
      }
    }
  }
}
```

## Rollback

The Assert Module has no rollback behavior — assertions are read-only and have no state to undo.
