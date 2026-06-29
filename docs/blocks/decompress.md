# Decompress Module

Extracts files from compressed archives with enhanced features including multiple format support, selective extraction, progress tracking, and improved rollback support.

## Usage

```
resource {
  type "file"
  source "archive.tar.gz"
  destination "extracted/"

  actions {
    decompress {
      format "tar.gz" # or "zip", "tar", "gz", "tgz"
      include "*.txt,*.log" # optional: extract only matching files
      exclude "*.tmp" # optional: exclude matching files
      preserveStructure true # optional: preserve directory structure (default: true)
    }
  }
}
```

## Properties

- `format` (required) - Archive format to decompress. Supported formats:
  - `zip` - ZIP archives
  - `tar` - TAR archives
  - `tar.gz` or `tgz` - GZIP-compressed TAR archives
  - `gz` - Single file GZIP compression
  - `tar.bz2` or `tbz2` - BZIP2-compressed TAR archives
  - `tar.xz` or `txz` - XZ-compressed TAR archives
  - `xz` - Single file XZ compression
  - `tar.z` or `tz` - ZLIB-compressed TAR archives
  - `z` - Single file ZLIB compression
- `include` (optional) - Comma-separated list of glob patterns for files to include in extraction
- `exclude` (optional) - Comma-separated list of glob patterns for files to exclude from extraction
- `preserveStructure` (optional) - Whether to preserve directory structure (default: true). When false, all files are extracted to the root destination directory
- `destination` (optional) - Target directory for extraction. If not specified, extracts to the current directory

## Enhanced Features

### Multiple Format Support
The decompress module supports a wide range of archive formats:
- **ZIP**: Standard ZIP archives with full directory structure support
- **TAR**: Uncompressed TAR archives
- **TAR.GZ/TGZ**: GZIP-compressed TAR archives
- **GZ**: Single file GZIP compression
- **TAR.BZ2/TBZ2**: BZIP2-compressed TAR archives
- **TAR.XZ/TXZ**: XZ-compressed TAR archives
- **XZ**: Single file XZ compression
- **TAR.Z/TZ**: ZLIB-compressed TAR archives
- **Z**: Single file ZLIB compression

### Selective Extraction
Use include and exclude patterns to extract only specific files:
- **Include patterns**: Only files matching these patterns will be extracted
- **Exclude patterns**: Files matching these patterns will be skipped
- **Glob support**: Full glob pattern matching (e.g., `*.txt`, `**/*.log`, `src/**`)

### Progress Tracking
The module provides real-time progress updates during extraction:
- File count tracking (total files vs. extracted files)
- Progress events every 10 files or at completion
- Detailed status messages for monitoring

### Structure Preservation Control
Control how files are extracted:
- **preserveStructure=true** (default): Maintains original directory structure
- **preserveStructure=false**: Flattens all files to the root destination directory

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

### Selective Extraction with Patterns
```
resource {
  type "file"
  source "application.zip"
  destination "app_files"

  actions {
    decompress {
      format "zip"
      include "*.js,*.css,*.html"  # Extract only web files
      exclude "*.min.*"            # Skip minified files
    }
  }
}
```

### Flatten Directory Structure
```
resource {
  type "file"
  source "nested_archive.tar.gz"
  destination "flat_files"

  actions {
    decompress {
      format "tar.gz"
      preserveStructure false  # All files go to root directory
    }
  }
}
```

### Extract Specific File Types
```
resource {
  type "file"
  source "logs.tar.gz"
  destination "extracted_logs"

  actions {
    decompress {
      format "tar.gz"
      include "**/*.log"  # Extract all log files recursively
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
- **Total Files**: Total number of files found in the archive
- **Extracted Files**: Number of files actually extracted (after filtering)
- **Include Patterns**: Applied include patterns for selective extraction
- **Exclude Patterns**: Applied exclude patterns for selective extraction
- **Preserve Structure**: Whether directory structure was preserved
- **Format**: Archive format used for decompression

This state information is preserved in the lockfile and used during rollback operations to ensure complete cleanup.

## Error Handling

- **Invalid Archives**: Handles corrupted or invalid archive files gracefully
- **Unsupported Formats**: Clear error messages for unsupported archive formats
- **Permission Issues**: Reports clear errors when extraction fails due to permissions
- **Disk Space**: Handles insufficient disk space during extraction
- **Binary Safety**: Properly handles binary content without UTF-8 conversion errors
- **Pattern Errors**: Graceful handling of invalid glob patterns with fallback to simple string matching
- **Missing Dependencies**: Informative errors for formats requiring additional packages (e.g., BZIP2)

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
