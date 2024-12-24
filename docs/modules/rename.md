# Rename Module

Renames files and directories with rollback capability.

## Usage

```
resource {
  source "oldname.txt"
  destination "newname.txt"

  actions {
    rename {
      overwrite false
    }
  }
}
```

## Properties

- `overwrite` (optional) - Whether to overwrite destination if it exists (default: false)

## Example

```
# Rename a config file
resource {
  source "app.conf.old"
  destination "app.conf"

  actions {
    backup {
      backup_path "app.conf.bak"
    }
    rename {
      overwrite true
    }
  }
}

# Rename directory with version
resource {
  type "directory"
  source "app-v1"
  destination "app-v2"

  actions {
    rename {
      overwrite false
    }
  }
}
```
