# Permissions Module

Manages file and directory permissions, ownership and modes.

## Usage

```
resource {
  source "script.sh"
  destination "~/bin/script.sh"

  actions {
    copy {}
    permissions {
      mode "755"
      owner "user"
      group "users"
      recursive false
    }
  }
}
```

## Properties

- `mode` (optional) - The octal permission mode (e.g. "644", "755")
- `owner` (optional) - The user owner of the file/directory
- `group` (optional) - The group owner of the file/directory
- `recursive` (optional) - Apply permissions recursively for directories (default: false)

## Example

```
# Set executable permissions on scripts
resource {
  source "scripts/"
  destination "~/bin"
  type "directory"

  actions {
    copy {
      recursive true
    }
    permissions {
      mode "755" # rwxr-xr-x
      recursive true
    }
  }
}

# Set restrictive permissions on sensitive files
resource {
  source "secrets/"
  destination "/etc/app/secrets"
  type "directory"

  actions {
    copy {
      recursive true
    }
    permissions {
      mode "600" # rw-------
      owner "app"
      group "app"
      recursive true
    }
  }
}
```
