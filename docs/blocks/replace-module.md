# Replace Module

Replaces text in files using regular expressions.

## Overview

The Replace Module searches files for regular expression patterns and replaces matches with specified text. It is ideal for surgical text modifications in configuration files.

## Features

- **Regex replacement**: Find and replace text by pattern
- **After/Before context**: Restrict replacements to lines after/before a match
- **Backup**: Create backup copies before modification
- **Ownership/permissions**: Set file owner, group, and mode
- **Multiple matches**: Replaces all occurrences by default
- **Idempotent**: Safe to run multiple times

## Properties

### Standard Properties
- `path` (required): File to edit
- `state` (required): `present` to apply replacement

### Replace Properties
- `regexp` (required): Regular expression to match
- `replace`: Replacement text (default: empty string — removes matches)
- `after`: Only replace text after the last match of this regex
- `before`: Only replace text before the first match of this regex
- `backup`: Create a backup file with `.bak` suffix (default: `false`)
- `owner`: File owner
- `group`: File group
- `mode`: File permissions (e.g., `0644`)

## Examples

### Simple Text Replacement

```configr
resource {
  type "replace"
  path "/etc/selinux/config"
  state "present"

  actions {
    replace {
      regexp "^SELINUX=enforcing"
      replace "SELINUX=disabled"
      backup "true"
    }
  }
}
```

### Remove Lines Matching a Pattern

```configr
resource {
  type "replace"
  path "/etc/hosts"
  state "present"

  actions {
    replace {
      regexp "^192\\.168\\.1\\.\\d+\\s+old-server"
      replace ""
    }
  }
}
```

### Replace Within a Section

```configr
resource {
  type "replace"
  path "/etc/ssh/sshd_config"
  state "present"

  actions {
    replace {
      regexp "^#?Port \\d+"
      replace "Port 2222"
      after "^# override defaults"
      backup "true"
    }
  }
}
```

## Rollback

The original file content is backed up before modification and restored on rollback.
