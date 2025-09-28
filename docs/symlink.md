# Symlink Module

Creates and manages symbolic links with support for bulk operations, validation, and conflict resolution.

## Usage

```
resource {
  source "~/dotfiles/bashrc"

  actions {
    symlink {
      link_path "~/.bashrc"
    }
  }
}
```

## Properties

- `link_path` (required) - Path where the symbolic link will be created
- `include_patterns` (optional) - List of glob patterns to include files for bulk operations
- `exclude_patterns` (optional) - List of glob patterns to exclude files from bulk operations
- `conflict_resolution` (optional) - How to handle existing symlinks: `skip` (default), `overwrite`, or `error`
- `show_progress` (optional) - Show progress for bulk operations (default: `true`)
- `validate_targets` (optional) - Validate that source files exist before creating symlinks (default: `true`)
- `create_directories` (optional) - Create destination directories if they don't exist (default: `true`)

## Examples

### Basic Symlink Creation

```
# Link dotfiles
resource {
  source "~/dotfiles/bashrc"

  actions {
    symlink {
      link_path "~/.bashrc"
    }
  }
}
```

### Directory Symlink

```
# Link config directory
resource {
  type "directory"
  source "~/projects/app/config"

  actions {
    symlink {
      link_path "~/.config/app"
    }
  }
}
```

### Bulk Operations with Patterns

```
# Link all .txt files from source directory
resource {
  source "~/dotfiles"

  actions {
    symlink {
      link_path "~/.config/dotfiles"
      include_patterns ["*.txt", "*.conf"]
      exclude_patterns ["*.bak", "*.tmp"]
    }
  }
}
```

### Conflict Resolution

```
# Overwrite existing symlinks
resource {
  source "~/dotfiles/vimrc"

  actions {
    symlink {
      link_path "~/.vimrc"
      conflict_resolution "overwrite"
    }
  }
}

# Skip existing symlinks (default behavior)
resource {
  source "~/dotfiles/vimrc"

  actions {
    symlink {
      link_path "~/.vimrc"
      conflict_resolution "skip"
    }
  }
}

# Error if symlink already exists
resource {
  source "~/dotfiles/vimrc"

  actions {
    symlink {
      link_path "~/.vimrc"
      conflict_resolution "error"
    }
  }
}
```

### Advanced Configuration

```
# Link with custom validation and directory creation
resource {
  source "~/dotfiles"

  actions {
    symlink {
      link_path "~/.config/dotfiles"
      include_patterns ["*.txt"]
      validate_targets false
      create_directories true
      show_progress true
    }
  }
}
```

### Link with Backup

```
# Link with backup
resource {
  source "~/dotfiles/vimrc"

  actions {
    backup {
      backup_path "~/.vimrc.bak"
    }
    symlink {
      link_path "~/.vimrc"
    }
  }
}
```

## Features

### Bulk Operations
- Create multiple symlinks from a directory using glob patterns
- Support for include/exclude patterns to filter files
- Progress tracking for large operations
- Automatic directory structure creation

### Validation
- Validate source files exist before creating symlinks
- Optional validation bypass for special cases
- Comprehensive error reporting

### Conflict Resolution
- **Skip** (default): Skip existing symlinks without error
- **Overwrite**: Replace existing symlinks with new ones
- **Error**: Throw exception if symlink already exists

### Progress Tracking
- Real-time progress updates for bulk operations
- File count and operation status reporting
- Configurable progress display

### Rollback Support
- Automatic rollback of created symlinks
- Restoration of original symlinks when overwritten
- Cleanup of created directories

## State Information

The symlink module provides detailed state information:

- `createdSymlinks`: Number of symlinks created
- `totalSymlinks`: Total number of symlinks processed
- `skippedSymlinks`: Number of symlinks skipped due to conflicts
- `overwrittenSymlinks`: Number of existing symlinks overwritten
- `failedSymlinks`: Number of symlinks that failed to create
- `createdPaths`: List of paths where symlinks were created
- `skippedPaths`: List of paths that were skipped
- `failedPaths`: List of paths that failed to create
- `hadToCreateDstDir`: Whether destination directory was created
- `symlinkExisted`: Whether the target symlink already existed
- `originalTarget`: Original target of existing symlink (for rollback)
