# BlockInFile Module

Inserts/updates/removes multi-line blocks in files — Ansible-style `blockinfile`.

## Overview

The BlockInFile Module manages multi-line blocks of text in files, similar to Ansible's `blockinfile` module. It wraps content between customizable marker lines, making it easy to manage blocks inserted by automation tools.

## Features

- **Marker-based insertion**: Wraps content between `BEGIN` and `END` markers
- **Customizable markers**: Configure the marker format with `{mark}` placeholder
- **Backup**: Create backup copies before modification
- **File creation**: Create the file if it doesn't exist
- **Ownership/permissions**: Set file owner, group, and mode
- **Multiple files**: Each path gets its own managed block

## Properties

### Standard Properties
- `path` (required): File to edit
- `state` (required): `present` to ensure block exists, `absent` to remove

### BlockInFile Properties
- `marker`: Marker line format (default: `# {mark} ANSIBLE MANAGED BLOCK`). `{mark}` is replaced with `BEGIN` or `END`
- `block`: The block content to insert (also accepts `content` as alias)
- `backup`: Create a backup file with `.bak` suffix (default: `false`)
- `create`: Create file if it doesn't exist (default: `false`)
- `owner`: File owner
- `group`: File group
- `mode`: File permissions (e.g., `0644`)

## Examples

### Insert a Managed Block

```configr
resource {
  type "blockinfile"
  path "/etc/hosts"
  state "present"

  actions {
    blockinfile {
      marker "# {mark} MANAGED HOSTS"
      block "192.168.1.10  app-server\n192.168.1.20  db-server"
      backup "true"
    }
  }
}
```

### Remove a Managed Block

```configr
resource {
  type "blockinfile"
  path "/etc/hosts"
  state "absent"

  actions {
    blockinfile {
      marker "# {mark} MANAGED HOSTS"
    }
  }
}
```

### Custom Marker and Content

```configr
resource {
  type "blockinfile"
  path "/etc/nginx/sites-available/default"
  state "present"

  actions {
    blockinfile {
      marker "# NGINX {mark}"
      block "location /static/ {\n    root /var/www/static;\n    expires 30d;\n}"
    }
  }
}
```

## Rollback

The original file content is backed up before modification and restored on rollback.
