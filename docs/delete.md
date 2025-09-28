# Delete Module

Safely deletes files and directories with optional backup and recursive deletion support.

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
- `recursive` (optional, boolean) - Enable recursive deletion for directories. Default: `false`

## Recursive Deletion

When `recursive` is set to `true`, the delete module can remove entire directory trees. This is particularly useful for cleaning up extracted archives or temporary directories.

```
resource {
  type "directory"
  source "temp_extracted_files/"
  
  actions {
    delete {
      recursive true
    }
  }
}
```

## Rollback Behavior

The delete module supports rollback operations:
- For files: Restores the original file from backup (if backup was configured)
- For directories with recursive deletion: Restores the entire directory structure from backup

## Examples

### Delete Single File with Backup
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
```

### Delete Directory Recursively
```
# Delete entire directory and all contents
resource {
  type "directory"
  source "logs/old/"

  actions {
    delete {
      recursive true
      backup {
        backup_path "backups/old_logs.tar.gz"
      }
    }
  }
}
```

### Cleanup Extracted Files
```
# Clean up extracted archive contents
resource {
  type "directory"
  source "mydir"

  actions {
    delete {
      recursive true
    }
  }
}
```

## Safety Features

- **Backup Support**: Always create backups before deletion for safety
- **Rollback Support**: Automatically restore files/directories during rollback operations
- **Recursive Control**: Explicit `recursive` flag prevents accidental directory deletion
- **State Tracking**: Tracks all deleted files and directories for proper rollback