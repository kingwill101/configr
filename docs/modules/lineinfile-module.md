# LineInFile Module

Ensures a specific line is present or absent in a file — Ansible-style `lineinfile`.

## Overview

The LineInFile Module manages individual lines in text files, similar to Ansible's `lineinfile` module. It is ideal for managing configuration files where a single line needs to be added, modified, or removed.

## Features

- **Regex matching**: Find target lines by regular expression
- **Insert before/after**: Insert new lines relative to existing content
- **Backup**: Create backup copies before modification
- **File creation**: Create the file if it doesn't exist (`create: true`)
- **Ownership/permissions**: Set file owner, group, and mode
- **Idempotent**: Multiple applies produce the same result

## Properties

### Standard Properties
- `path` (required): File to edit
- `state` (required): `present` to ensure line exists, `absent` to remove

### LineInFile Properties
- `regexp`: Regular expression to find the target line
- `line`: The line content to ensure (supports back-references `\1`, `\2`, etc.)
- `insert_after`: Insert after the last match of this regex (default: `EOF`)
- `insert_before`: Insert before the first match of this regex
- `backup`: Create a backup file with `.bak` suffix (default: `false`)
- `create`: Create file if it doesn't exist (default: `false`)
- `owner`: File owner
- `group`: File group
- `mode`: File permissions (e.g., `0644`)

## Examples

### Ensure a Line is Present

```configr
resource {
  type "lineinfile"
  path "/etc/ssh/sshd_config"
  state "present"

  actions {
    lineinfile {
      regexp "^#?PermitRootLogin"
      line "PermitRootLogin no"
      backup "true"
    }
  }
}
```

### Ensure a Line is Absent

```configr
resource {
  type "lineinfile"
  path "/etc/sudoers"
  state "absent"

  actions {
    lineinfile {
      regexp "^lazyuser"
      line "lazyuser ALL=(ALL) ALL"
    }
  }
}
```

### Insert Line After Match

```configr
resource {
  type "lineinfile"
  path "/etc/nginx/nginx.conf"
  state "present"

  actions {
    lineinfile {
      regexp "^http {"
      line "    client_max_body_size 100M;"
      insert_after "^http {"
    }
  }
}
```

### Create File with Content

```configr
resource {
  type "lineinfile"
  path "~/.config/myapp/config"
  state "present"

  actions {
    lineinfile {
      line "feature_enabled=true"
      create "true"
    }
  }
}
```
