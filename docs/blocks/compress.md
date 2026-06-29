# Compress Module

Compresses files and directories into archives with support for multiple formats, compression levels, and selective compression.

## Usage

```
resource {
  type "directory"
  source "logs/"
  destination "archive.tar.gz"

  actions {
    compress {
      format "tar.gz"           # Archive format
      recursive true             # Include subdirectories
      compressionLevel 9         # Compression level (1-9)
      include "*.log,*.txt"      # Include only matching files
      exclude "*.tmp,*.cache"    # Exclude matching files
      preserveStructure true     # Preserve directory structure
    }
  }
}
```

## Properties

### Required Properties
- `format` - Archive format to create. Supported formats:
  - `zip` - Creates ZIP archive
  - `tar` - Creates TAR archive (uncompressed)
  - `tar.gz` or `tgz` - Creates gzipped tar archive
  - `gz` - Creates gzipped file (single file only)
  - `tar.bz2` or `tbz2` - Creates BZIP2-compressed tar archive
  - `tar.xz` or `txz` - Creates XZ-compressed tar archive
  - `xz` - Creates XZ-compressed file (single file only)
  - `tar.z` or `tz` - Creates ZLIB-compressed tar archive
  - `z` - Creates ZLIB-compressed file (single file only)

### Optional Properties
- `recursive` - Include subdirectories when compressing (default: false)
- `compressionLevel` - Compression level from 1 (fastest) to 9 (best compression) (default: 6)
- `include` - Comma-separated list of glob patterns for files to include
- `exclude` - Comma-separated list of glob patterns for files to exclude
- `preserveStructure` - Whether to preserve directory structure in archive (default: true)

## Examples

### Basic Archive Creation
```
# Archive old logs
resource {
  type "directory"
  source "/var/log/app/old"
  destination "/backup/logs.tar.gz"

  actions {
    compress {
      format "tar.gz"
      recursive true
    }
  }
}
```

### High Compression Archive
```
# Create highly compressed archive for long-term storage
resource {
  type "directory"
  source "project/"
  destination "project_backup.zip"

  actions {
    compress {
      format "zip"
      recursive true
      compressionLevel 9  # Maximum compression
    }
  }
}
```

### Compression Level Comparison
```
# Fast compression for quick backups
resource {
  type "directory"
  source "temp_data/"
  destination "quick_backup.zip"

  actions {
    compress {
      format "zip"
      recursive true
      compressionLevel 1  # Fast compression
    }
  }
}

# Maximum compression for archival storage
resource {
  type "directory"
  source "important_data/"
  destination "archive_backup.zip"

  actions {
    compress {
      format "zip"
      recursive true
      compressionLevel 9  # Maximum compression
    }
  }
}
```

### Selective File Compression
```
# Archive only specific file types
resource {
  type "directory"
  source "source_code/"
  destination "code_archive.zip"

  actions {
    compress {
      format "zip"
      recursive true
      include "*.dart,*.yaml,*.md"  # Only include source files
      exclude "*.tmp,*.log,node_modules/"  # Exclude temporary files
    }
  }
}
```

### Flatten Directory Structure
```
# Create archive without preserving directory structure
resource {
  type "directory"
  source "documents/"
  destination "flat_docs.zip"

  actions {
    compress {
      format "zip"
      recursive true
      preserveStructure false  # All files in root of archive
    }
  }
}
```

### Single File Compression
```
# Compress a single large file
resource {
  type "file"
  source "large_database.sql"
  destination "database.sql.gz"

  actions {
    compress {
      format "gz"  # GZIP compression for single files
      compressionLevel 6
    }
  }
}
```

### Multi-format Archive Pipeline
```
# Create multiple archive formats
resource {
  type "directory"
  source "data/"
  destination "backup"

  actions {
    # Create ZIP archive for Windows compatibility
    compress {
      format "zip"
      recursive true
      compressionLevel 5
      destination "backup.zip"
    }

    # Create TAR.GZ for Unix systems
    compress {
      format "tar.gz"
      recursive true
      compressionLevel 9
      destination "backup.tar.gz"
    }
  }
}
```

### Archive with Validation
```
# Package application files with validation
resource {
  type "directory"
  source "dist/"
  destination "app.zip"

  actions {
    # First ensure proper permissions
    permissions {
      mode "644"
      recursive true
    }

    # Then create archive
    compress {
      format "zip"
      recursive true
      compressionLevel 8
    }

    # Validate the archive
    validate {
      format "zip"
    }
  }
}
```

### Archive with Backup
```
# Archive with backup before compression
resource {
  type "directory"
  source "config/"
  destination "config.tar.gz"

  actions {
    backup {
      backup_path "config.tar.gz.bak"
    }
    compress {
      format "tar.gz"
      recursive true
      compressionLevel 7
    }
  }
}
```

## Enhanced Features

### Multiple Format Support
The compress module supports a wide range of archive formats:
- **ZIP**: Standard ZIP archives with full directory structure support
- **TAR**: Uncompressed TAR archives
- **TAR.GZ/TGZ**: GZIP-compressed TAR archives
- **GZ**: Single file GZIP compression
- **TAR.BZ2/TBZ2**: BZIP2-compressed TAR archives (better compression than GZIP)
- **TAR.XZ/TXZ**: XZ-compressed TAR archives (best compression ratio)
- **XZ**: Single file XZ compression
- **TAR.Z/TZ**: ZLIB-compressed TAR archives
- **Z**: Single file ZLIB compression

### Compression Level Support
All compression formats support configurable compression levels:
- **1-3**: Fast compression, larger file size
- **4-6**: Balanced compression (default: 6)
- **7-9**: High compression, slower processing

### Selective Compression
Use include and exclude patterns to compress only specific files:
- **Include patterns**: Only files matching these patterns will be compressed
- **Exclude patterns**: Files matching these patterns will be skipped

### Structure Preservation Control
- **preserveStructure=true** (default): Maintains directory structure in archives
- **preserveStructure=false**: Flattens all files to root directory

## Advanced Usage

### Pattern Matching
The `include` and `exclude` properties support glob patterns:
- `*.txt` - All text files
- `**/*.log` - All log files in any subdirectory
- `src/**` - All files in src directory and subdirectories
- `!*.tmp` - Exclude temporary files

### Compression Level Guidelines
- **1-3**: Fast compression, larger file size
- **4-6**: Balanced compression (default: 6)
- **7-9**: High compression, slower processing
- **0**: Store uncompressed (ZIP format only)

**Note**: Compression levels are now fully implemented and will produce different file sizes. Level 9 will create smaller archives than level 1, but will take longer to process.

### Format Selection
- **ZIP**: Best for cross-platform compatibility
- **TAR.GZ**: Best for Unix/Linux systems
- **TAR.BZ2**: Better compression than GZIP, good for large files
- **TAR.XZ**: Best compression ratio, ideal for long-term storage
- **TAR.Z**: ZLIB compression, good balance of speed and compression
- **TAR**: Uncompressed, fastest creation
- **GZ**: Single file compression only
