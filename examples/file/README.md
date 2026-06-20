# File Module Example

This example demonstrates the comprehensive capabilities of the Configr File Module for file management operations.

## Overview

The File Module provides powerful file management capabilities including:
- Creating files with custom content
- Editing existing files with multiple modes
- Removing files with optional backup
- Automatic directory creation
- Complete rollback support

## What This Example Demonstrates

### 1. File Creation
- **app.conf**: Application configuration file with key-value pairs
- **setup.sh**: Executable shell script for environment setup
- **config.json**: JSON configuration file with nested structure
- **README.md**: Markdown documentation file
- **nginx.conf**: Complex nginx server configuration
- **demo.py**: Python script that reads and displays configuration

### 2. File Editing
- **Append Mode**: Adding additional settings to `app.conf`
- **Prepend Mode**: Adding header comments to `nginx.conf`

### 3. File Management
- **Temporary File**: Creates and then removes a temporary file
- **Backup Support**: Demonstrates backup functionality during edits

### 4. Directory Creation
- All examples use `create_directories="true"` to ensure parent directories exist

## Files Created

After running this example, you'll find the following files in the `examples/file/` directory:

```
examples/file/
├── app.conf          # Application configuration
├── app.conf.backup   # Backup of app.conf after edit
├── setup.sh          # Shell setup script
├── config.json       # JSON configuration
├── README.md         # Documentation
├── nginx.conf        # Nginx configuration
├── nginx.conf.backup # Backup of nginx.conf after edit
└── demo.py           # Python demo script
```

## Running the Example

### Apply Configuration
```bash
cd examples/file
dart run ../../bin/main.dart apply
```

### Rollback Changes

#### Rollback All Operations
```bash
dart run ../../bin/main.dart rollback
```

#### Rollback Individual Operations
```bash
# Rollback the last operation
dart run ../../bin/main.dart rollback -n 1

# Rollback the last 3 operations
dart run ../../bin/main.dart rollback -n 3
```

#### Rollback Behavior
- **Create Operations**: Files created by the module are removed during rollback
- **Edit Operations**: Original content is restored from backup files
- **Remove Operations**: Removed files are restored from backup files
- **Backup Management**: Backup files are automatically created and cleaned up

## Example Operations

### 1. Basic File Creation
```configr
resource {
  type "file"
  source "examples/file/app.conf"
  destination "examples/file/app.conf"

  actions {
    file {
      operation "create"
      content "app_name=ConfigrDemo\nversion=1.0.0\ndebug=false"
      create_directories "true"
    }
  }
}
```

### 2. File Editing (Append Mode)
```configr
resource {
  type "file"
  source "examples/file/app.conf"
  destination "examples/file/app.conf"

  actions {
    file {
      operation "edit"
      content "\n# Additional settings\nfeature_enabled=true"
      edit_mode "append"
      backup_original "true"
    }
  }
}
```

### 3. File Removal
```configr
resource {
  type "file"
  source "examples/file/temp.txt"
  destination "examples/file/temp.txt"

  actions {
    file {
      operation "remove"
      backup_original "true"
    }
  }
}
```

## Key Features Demonstrated

### Multiple File Formats
- **Configuration Files**: `.conf` files with key-value pairs
- **Scripts**: Shell scripts (`.sh`) and Python scripts (`.py`)
- **Data Files**: JSON configuration files
- **Documentation**: Markdown files
- **Server Configs**: Nginx configuration files

### Edit Modes
- **Replace**: Complete file replacement
- **Append**: Add content to the end of existing files
- **Prepend**: Add content to the beginning of existing files

### Backup and Safety
- **Backup Creation**: Automatic backup of files before modification
- **Custom Backup Suffixes**: Configurable backup file naming
- **Rollback Support**: Complete rollback of all file operations

### Directory Management
- **Automatic Creation**: Parent directories created automatically
- **Path Resolution**: Proper handling of relative and absolute paths

## Integration Possibilities

This example can be extended to integrate with other Configr modules:

### With Git Module
```configr
# After file operations, commit changes to git
resource {
  type "directory"
  source "."
  destination "."

  actions {
    git {
      operation "commit"
      local_path "."
      commit_message "Add configuration files"
    }
  }
}
```

### With Execute Module
```configr
# Make scripts executable
resource {
  type "file"
  source "examples/file/setup.sh"
  destination "examples/file/setup.sh"

  actions {
    execute {
      command "chmod +x examples/file/setup.sh"
    }
  }
}
```

## Best Practices Shown

1. **Always Use Backups**: Set `backup_original="true"` for important files
2. **Create Directories**: Use `create_directories="true"` to ensure paths exist
3. **Meaningful Content**: Provide well-formatted, readable file content
4. **Descriptive Names**: Use clear, descriptive file names and paths
5. **Test Rollback**: Always test rollback functionality

## Troubleshooting

### Common Issues
- **Permission Errors**: Ensure write permissions for target directories
- **Path Issues**: Verify that destination paths are correct
- **Content Formatting**: Check that file content is properly formatted

### Verification
After running the example, you can verify the results:
```bash
# List created files
ls -la examples/file/

# Check file content
cat examples/file/app.conf

# Run the Python demo
python3 examples/file/demo.py
```

## Next Steps

- Explore the [File Module Documentation](../../docs/modules/file-module.md)
- Try the [Git Module Example](../git/README.md) for version control integration
- Check out other [Configr Examples](../README.md) for more use cases
