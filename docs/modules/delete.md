# Delete Module

Safely deletes files and directories with optional backup.

## Usage

```
resource {
  source "file-to-delete.txt"

  actions {
    delete {
      backup {
        backup_path "backups/file-to-delete.bak"
      }
    }
  }
}
```

## Properties

- `backup` (optional) - Backup configuration before deletion
  - `backup_path` - Path where backup will be stored

## Example

```
# Delete with backup
resource {
  source "old_config.json"

  actions {
    delete {
      backup {
        backup_path "~/backups/old_config.json.bak"
      }
    }
  }
}

# Delete old logs directory
resource {
  type "directory"
  source "logs/old/"

  actions {
    backup {
      backup_path "backups/old_logs.tar.gz"
      recursive true
    }
    delete {}
  }
}
```
