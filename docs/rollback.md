# Rollback Command

The rollback command allows you to undo configuration changes by reversing completed operations from the most recent configuration run.

## Overview

When configr applies a configuration, it tracks all completed operations in a lockfile. The rollback command uses this lockfile data to identify and reverse these operations, restoring your system to its previous state.

## Usage

```bash
configr rollback [options]
```

## Options

- `--dry-run` - Show what would be rolled back without making changes
- `--verbose` - Show detailed output during rollback
- `--force` - Skip confirmation prompts
- `--lockfile <path>` - Use a specific lockfile (default: .configr.lock)

## How Rollback Works

1. **Reads Lockfile**: Parses the lockfile to identify completed resources and actions
2. **State Restoration**: Restores module state from lockfile data
3. **Reverse Operations**: Executes rollback logic for each completed action in reverse order
4. **Cleanup**: Removes the lockfile after successful rollback

## Module Rollback Behavior

### Copy Module
- Removes copied files and directories
- Restores original file locations if they were overwritten

### Delete Module
- Restores deleted files from backup (if backup was configured)
- Recreates deleted directories and their contents

### Decompress Module
- **Enhanced Behavior**: Removes the entire destination directory recursively
- Cleans up all extracted files and created directories
- Handles large archive extractions efficiently

### Compress Module
- Removes created archive files
- Restores original directory structure if it was modified

### Move Module
- Moves files and directories back to their original locations
- Restores original file structure

### Permissions Module
- Restores original file permissions and ownership
- Handles both individual files and recursive directory permissions

### Symlink Module
- Removes created symbolic links
- Restores original files if they were replaced by symlinks

### Backup Module
- Restores files from backups
- Removes backup files if they were created during the operation

## Examples

### Basic Rollback
```bash
configr rollback
```
Rolls back all changes from the most recent configuration run.

### Dry Run
```bash
configr rollback --dry-run
```
Shows what would be rolled back without making any changes.

### Verbose Rollback
```bash
configr rollback --verbose
```
Provides detailed output showing each rollback operation.

### Force Rollback
```bash
configr rollback --force
```
Skips confirmation prompts and proceeds with rollback.

## Rollback Scenarios

### Archive Extraction Rollback
```
# Original configuration
resource {
  type "file"
  source "large_archive.zip"
  destination "extracted/"

  actions {
    decompress {
      format "zip"
    }
  }
}

# Rollback behavior:
# - Entire "extracted/" directory is removed recursively
# - All extracted files and subdirectories are cleaned up
```

### Directory Operations Rollback
```
# Original configuration
resource {
  type "directory"
  source "temp_files/"

  actions {
    delete {
      recursive true
      backup {
        backup_path "backups/temp_files.tar.gz"
      }
    }
  }
}

# Rollback behavior:
# - "temp_files/" directory is restored from backup
# - All original files and subdirectories are recreated
```

### File Copy Rollback
```
# Original configuration
resource {
  source "config.json"
  destination "~/.app/config.json"

  actions {
    backup {
      backup_path "~/.app/config.json.bak"
    }
    copy {}
    permissions {
      mode "644"
    }
  }
}

# Rollback behavior:
# - ~/.app/config.json is restored from backup
# - Original permissions are restored
# - Backup file is removed
```

## Error Handling

### Missing Lockfile
If the lockfile is missing, rollback will:
- Display an error message
- Exit without making changes
- Suggest running with `--lockfile` to specify a different lockfile

### Partial Failures
If rollback fails for some operations:
- Continues with remaining rollback operations
- Reports which operations failed
- Provides details about the failures
- Preserves lockfile for potential retry

### Backup Recovery
If rollback requires backups that are missing:
- Reports missing backup files
- Continues with operations that don't require backups
- Logs warnings for incomplete rollbacks

## Best Practices

### Always Backup Important Files
```
resource {
  source "critical.conf"
  destination "/etc/critical.conf"

  actions {
    backup {
      backup_path "/backups/critical.conf.$(date)"
    }
    copy {}
  }
}
```

### Test with Dry Run
Always test rollback operations with `--dry-run` first:
```bash
configr rollback --dry-run --verbose
```

### Keep Lockfiles Safe
- Don't manually edit lockfiles
- Preserve lockfiles until you're sure changes are permanent
- Back up lockfiles for critical system changes

### Monitor Rollback Output
Use verbose mode to monitor rollback progress:
```bash
configr rollback --verbose
```

## Troubleshooting

### "No lockfile found"
- Ensure you're in the correct directory
- Check if `.configr.lock` exists
- Use `--lockfile` to specify the correct path

### "Permission denied during rollback"
- Ensure you have necessary permissions for file operations
- Run with elevated privileges if needed
- Check file ownership and permissions

### "Backup file not found"
- Some operations require backup files for rollback
- Ensure backups were created during the original operation
- Check backup file paths and permissions

### "Rollback incomplete"
- Review verbose output for specific failures
- Address individual file permission or access issues
- Retry rollback after fixing underlying problems

## Security Considerations

- Rollback operations require the same permissions as the original operations
- Backup files should be protected with appropriate permissions
- Consider the security implications of restoring previous file states
- Be cautious when rolling back permission changes on sensitive files

## Integration with Other Commands

The rollback command works with:
- `configr apply` - Creates lockfiles that rollback uses
- `configr validate` - Can check configuration before rollback
- `configr status` - Shows current configuration state

Use these commands together for safe configuration management workflows.