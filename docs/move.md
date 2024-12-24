# Move Module

Moves or renames files and directories with rollback support.

## Usage

```
resource {
  source "old_location/file.txt"
  destination "new_location/file.txt"

  actions {
    move {
      overwrite false
    }
  }
}
```

## Properties

- `overwrite` (optional) - Whether to overwrite existing files at destination (default: false)

## Example

```
# Move a file
resource {
  source "/tmp/config.json"
  destination "/etc/app/config.json"

  actions {
    backup {
      backup_path "/tmp/config.json.bak"
    }
    move {
      overwrite true
    }
    permissions {
      mode "644"
    }
  }
}

# Move a directory
resource {
  source "/old/app"
  destination "/new/app"
  type "directory"

  actions {
    move {
      overwrite false
    }
    permissions {
      recursive true
      mode "755"
    }
  }
}
```
