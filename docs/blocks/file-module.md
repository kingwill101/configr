# File Module

The File Module provides comprehensive file management capabilities for creating, editing, and removing files in your dotfile management workflows.

## Overview

The File Module is designed to handle file operations with full rollback support, making it perfect for dotfile management scenarios where you need to create configuration files, modify existing files, or clean up files as part of your setup process.

## Features

- **File Creation**: Create new files with custom content
- **File Editing**: Modify existing files with multiple edit modes
- **File Removal**: Safely remove files with optional backup
- **Directory Creation**: Automatically create parent directories
- **Backup Support**: Optional backup of original files before modification
- **Rollback Support**: Complete rollback functionality for all operations
- **Validation**: Comprehensive input validation and error handling

## Operations

### Create Operation

Creates a new file with the specified content.

```configr
resource {
  type "file"
  destination "path/to/destination.txt"

  actions {
    file {
      operation "create"
      content "File content here"
      create_directories "true"
    }
  }
}
```

**Properties:**
- `operation`: Must be `"create"`
- `content`: The content to write to the file
- `create_directories`: Whether to create parent directories (default: `true`)
- `backup_original`: Whether to backup existing files (default: `false`)

### Edit Operation

Modifies an existing file using different edit modes.

```configr
resource {
  type "file"
  destination "path/to/existing.txt"

  actions {
    file {
      operation "edit"
      content "\nAdditional content"
      edit_mode "append"
      backup_original "true"
    }
  }
}
```

**Properties:**
- `operation`: Must be `"edit"`
- `content`: The content to add or replace
- `edit_mode`: How to edit the file (`"replace"`, `"append"`, `"prepend"`)
- `backup_original`: Whether to backup the original file (default: `false`)

**Edit Modes:**
- `replace`: Replace the entire file content
- `append`: Add content to the end of the file
- `prepend`: Add content to the beginning of the file

### Remove Operation

Removes a file with optional backup.

```configr
resource {
  type "file"
  destination "path/to/file.txt"

  actions {
    file {
      operation "remove"
      backup_original "true"
    }
  }
}
```

**Properties:**
- `operation`: Must be `"remove"`
- `backup_original`: Whether to backup before removal (default: `false`)

## Configuration Properties

### Required Properties

- `operation`: The operation to perform (`"create"`, `"edit"`, `"remove"`)

### Optional Properties

- `content`: File content (required for `create` and `edit` operations)
- `create_directories`: Create parent directories if they don't exist (default: `true`)
- `backup_original`: Backup original file before modification (default: `false`)
- `backup_suffix`: Suffix for backup files (default: `".backup"`)
- `edit_mode`: Edit mode for edit operation (default: `"replace"`)

### Standard Properties

- `destination`: Destination path (required - used for file operations)

## Examples

### Basic File Creation

```configr
resource {
  type "file"
  destination "~/.bashrc"

  actions {
    file {
      operation "create"
      content "# My custom bash configuration\nexport PATH=\$PATH:/usr/local/bin"
      create_directories "true"
    }
  }
}
```

### Appending to Configuration File

```configr
resource {
  type "file"
  destination "~/.zshrc"

  actions {
    file {
      operation "edit"
      content "\n# Additional aliases\nalias ll='ls -la'\nalias la='ls -A'"
      edit_mode "append"
      backup_original "true"
    }
  }
}
```

### Creating Configuration with Backup

```configr
resource {
  type "file"
  destination "~/.gitconfig"

  actions {
    file {
      operation "create"
      content "[user]\n    name = John Doe\n    email = john@example.com\n[core]\n    editor = vim"
      backup_original "true"
    }
  }
}
```

### Removing Temporary Files

```configr
resource {
  type "file"
  destination "/tmp/temp-file.txt"

  actions {
    file {
      operation "remove"
    }
  }
}
```

## Integration with Other Modules

### File Creation + Git Commit

```configr
resources {
  # Create a new configuration file
  resource {
    type "file"
    destination "config/app.conf"

    actions {
      file {
        operation "create"
        content "app_name=MyApp\nversion=1.0.0\ndebug=false"
        create_directories "true"
      }
    }
  }

  # Commit the new file to git
  resource {
    type "directory"
    destination "."

    actions {
      git {
        operation "commit"
        local_path "."
        commit_message "Add application configuration"
      }
    }
  }
}
```

### File Editing + Git Operations

```configr
resources {
  # Edit existing configuration
  resource {
    type "file"
    destination "config/settings.conf"

    actions {
      file {
        operation "edit"
        content "\n# New setting\nfeature_enabled=true"
        edit_mode "append"
        backup_original "true"
      }
    }
  }

  # Commit the changes
  resource {
    type "directory"
    destination "."

    actions {
      git {
        operation "commit"
        local_path "."
        commit_message "Enable new feature"
      }
    }
  }
}
```

## Rollback Behavior

The File Module provides comprehensive rollback support with automatic state tracking and backup management:

### Rollback Operations

#### Create Operation Rollback
- **Behavior**: Removes files that were created by the operation
- **State Tracking**: Tracks whether the file existed before creation (`fileExisted: false`)
- **Backup**: No backup needed for new files

#### Edit Operation Rollback  
- **Behavior**: Restores original content from backup files
- **State Tracking**: Tracks original content, backup path, and file existence
- **Backup Management**: Creates backup before editing, cleans up after rollback

#### Remove Operation Rollback
- **Behavior**: Restores removed files from backup files
- **State Tracking**: Tracks original content and backup path
- **Backup Management**: Creates backup before removal, cleans up after rollback

### State Persistence

The module automatically saves all necessary state to the lockfile for rollback:

```json
{
  "operation": "edit",
  "filePath": "/path/to/file.txt",
  "originalContent": "Original file content",
  "backupPath": "/path/to/file.txt.backup",
  "fileExisted": true,
  "operationSuccess": true
}
```

### Rollback Examples

#### Rolling Back Individual Operations
```bash
# Rollback the last operation
configr rollback --count 1

# Rollback the last 3 operations  
configr rollback --count 3
```

#### Rolling Back All Operations
```bash
# Rollback all operations
configr rollback
```

### Backup File Management

- **Automatic Creation**: Backup files are created when `backup_original: true`
- **Automatic Cleanup**: Backup files are removed after successful rollback
- **Custom Suffix**: Use `backup_suffix` to customize backup file naming
- **Cross-Platform**: Works on all supported operating systems

### Lockfile Integration

The File Module integrates seamlessly with Configr's lockfile system:

- **State Persistence**: All operation state is automatically saved to the lockfile
- **Rollback Support**: State is restored from lockfile during rollback operations
- **Operation Tracking**: Each operation is tracked with success/failure status
- **Timestamp Recording**: All operations include timestamps for audit trails

### Rollback Safety Features

- **Atomic Operations**: Rollback operations are atomic - either complete or fail cleanly
- **State Validation**: Rollback validates state before attempting restoration
- **Error Recovery**: Failed rollbacks provide detailed error messages
- **Backup Verification**: Backup files are verified before restoration

## Error Handling

The File Module provides detailed error messages for common scenarios:

- **Missing file path**: When `destination` is empty or not specified
- **File not found**: When trying to edit a non-existent file
- **Invalid operation**: When an unsupported operation is specified
- **Invalid edit mode**: When an unsupported edit mode is specified
- **Permission errors**: When file operations fail due to permissions

## Best Practices

1. **Use Backup**: Always set `backup_original="true"` when modifying important configuration files
2. **Create Directories**: Use `create_directories="true"` to ensure parent directories exist
3. **Meaningful Content**: Provide clear, well-formatted content for configuration files
4. **Test Rollback**: Always test rollback functionality before deploying to production
5. **Combine with Git**: Use file operations with git commits for version control

## Troubleshooting

### File Not Created
- Check that `destination` path is specified
- Verify parent directories exist or `create_directories` is enabled
- Check file permissions

### Edit Operation Fails
- Ensure the file exists before editing
- Verify the file is not locked by another process
- Check file permissions

### Rollback Issues
- Ensure backup files are not manually deleted
- Check that the original file path is still valid
- Verify rollback permissions

## See Also

- [Git Module Documentation](git.md)
- [Network Module Documentation](network.md)
- [Configuration Guide](../getting-started/cli-usage.md)
- [Rollback Guide](../reference/rollback.md)
