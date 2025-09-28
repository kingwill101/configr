# Decompress Module

Extracts files from compressed archives with improved rollback support and binary file handling.

## Usage

```
resource {
  type "file"
  source "archive.tar.gz"
  destination "extracted/"

  actions {
    decompress {
      format "tar.gz" # or "zip"
    }
  }
}
```

## Properties

- `format` (required) - Archive format to decompress. Supported formats:
  - `tar.gz`
  - `zip`
- `destination` (optional) - Target directory for extraction. If not specified, extracts to the current directory

## Binary File Support

The decompress module properly handles binary archives by reading them as binary data rather than text. This ensures that compressed files of any type (images, executables, etc.) are extracted correctly without corruption.

## Rollback Behavior

The decompress module has enhanced rollback capabilities:

- **Complete Cleanup**: During rollback, the entire destination directory is removed recursively
- **State Restoration**: Properly restores state from lockfile data to identify all created files and directories
- **Safe Removal**: Only removes files and directories that were created during the decompress operation

## Examples

### Extract ZIP Archive
```
resource {
  type "file"
  source "backup.zip"
  destination "restored_files"

  actions {
    decompress {
      format "zip"
    }
  }
}
```

### Extract TAR.GZ with Permissions
```
resource {
  source "backups/config.tar.gz"
  destination "~/.config"

  actions {
    # Extract configs
    decompress {
      format "tar.gz"
    }

    # Set proper permissions
    permissions {
      mode "644"
      recursive true
    }
  }
}
```

### Large Archive Extraction
```
resource {
  type "file"
  source "large_dataset.zip"
  destination "data/"

  actions {
    decompress {
      format "zip"
    }
    # On rollback, entire "data/" directory will be removed
  }
}
```

### Multiple Archives
```
resource {
  type "file"
  source "app_v1.tar.gz"
  destination "app/"

  actions {
    decompress {
      format "tar.gz"
    }
  }
}

resource {
  type "file"
  source "app_v2.tar.gz"
  destination "app/"

  actions {
    decompress {
      format "tar.gz"
    }
  }
}
```

## State Management

The decompress module tracks:
- **Created Files**: All files extracted from the archive
- **Created Directories**: All directories created during extraction
- **Destination Path**: The target extraction directory

This state information is preserved in the lockfile and used during rollback operations to ensure complete cleanup.

## Error Handling

- **Invalid Archives**: Handles corrupted or invalid archive files gracefully
- **Permission Issues**: Reports clear errors when extraction fails due to permissions
- **Disk Space**: Handles insufficient disk space during extraction
- **Binary Safety**: Properly handles binary content without UTF-8 conversion errors

## Integration with Other Modules

The decompress module works well with other configr modules:

- **Delete Module**: Use `delete { recursive true }` for manual cleanup
- **Permissions Module**: Set proper permissions after extraction
- **Backup Module**: Create backups before overwriting existing files
- **Validate Module**: Verify extracted contents

```
resource {
  type "file"
  source "archive.zip"
  destination "extracted"

  actions {
    # Extract archive
    decompress {
      format "zip"
    }

    # Set permissions
    permissions {
      mode "755"
      recursive true
    }

    # Validate extraction
    validate {
      exists true
    }
  }
}
```
