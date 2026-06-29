# Delete Module

Enhanced file and directory deletion with selective deletion, progress tracking, and safe deletion options.

## Features

- **Selective Deletion**: Include/exclude files using glob patterns
- **Safe Deletion**: Trash support and confirmation prompts
- **Progress Tracking**: Real-time progress monitoring with detailed counters
- **Backup Support**: Optional backup before deletion
- **Event System**: Comprehensive event emission for monitoring and logging
- **Rollback Support**: Ability to restore deleted files from backup

## Basic Usage

### Simple File Delete

```
resource {
  source "/path/to/file.txt"
  actions {
    delete {}
  }
}
```

### Directory Delete

```
resource {
  source "/path/to/directory"
  actions {
    delete {
      recursive true
    }
  }
}
```


### Selective Deletion with Patterns

#### Include Patterns

Delete only specific file types:

```
resource {
  source "/path/to/directory"
  actions {
    delete {
      recursive true
      include "*.tmp"
    }
  }
}
```

Delete multiple file types:

```
resource {
  source "/path/to/directory"
  actions {
    delete {
      recursive true
      include "*.tmp,*.log,*.cache"
    }
  }
}
```

#### Exclude Patterns

Skip specific file types:

```
resource {
  source "/path/to/directory"
  actions {
    delete {
      recursive true
      exclude "*.important"
    }
  }
}
```

### Safe Deletion Options

#### Use Trash

Move files to trash instead of permanent deletion:

```
resource {
  source "/path/to/file.txt"
  actions {
    delete {
      use_trash true
    }
  }
}
```

#### Require Confirmation

Prompt for confirmation before deletion:

```
resource {
  source "/path/to/important/file.txt"
  actions {
    delete {
      require_confirmation true
    }
  }
}
```

### Backup Before Deletion

```
resource {
  source "/path/to/file.txt"
  actions {
    delete {
      backup {
        backup_path "/backup/file.txt.bak"
      }
    }
  }
}
```

## Configuration Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `recursive` | boolean | `false` | Delete directories recursively |
| `include` | string/array | `[]` | Glob patterns for files to include |
| `exclude` | string/array | `[]` | Glob patterns for files to exclude |
| `use_trash` | boolean | `false` | Move to trash instead of permanent deletion |
| `require_confirmation` | boolean | `false` | Prompt for confirmation before deletion |
| `backup` | object | `null` | Backup configuration |
| `backup.backup_path` | string | `null` | Path where backup will be stored |

## Pattern Matching

The delete module uses glob patterns for file selection. Supported patterns include:

- `*` - Matches any characters
- `?` - Matches any single character
- `[abc]` - Matches any character in the set
- `[a-z]` - Matches any character in the range
- `**` - Matches any number of directories

### Pattern Examples

```
# Delete all temporary files
include "*.tmp"

# Delete all files starting with 'temp'
include "temp*"

# Delete all files in subdirectories
include "**/*.tmp"

# Exclude important files
exclude "*.important,*.backup"
```

## State Tracking

The delete module tracks detailed state information:

### State Properties

| Property | Type | Description |
|----------|------|-------------|
| `deletedFiles` | int | Number of files successfully deleted |
| `skippedFiles` | int | Number of files skipped (excluded or not included) |
| `trashedFiles` | int | Number of files moved to trash |
| `totalFiles` | int | Total number of files processed |
| `includePatterns` | array | Active include patterns |
| `excludePatterns` | array | Active exclude patterns |
| `useTrash` | boolean | Whether trash is being used |
| `requireConfirmation` | boolean | Whether confirmation is required |

