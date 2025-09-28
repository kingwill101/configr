# Copy Module 

Enhanced file and directory copying with selective copying, progress tracking, and conflict resolution.

## Features

- **Selective Copying**: Include/exclude files using glob patterns
- **Progress Tracking**: Real-time progress monitoring with detailed counters
- **Conflict Resolution**: Multiple strategies for handling existing files
- **Event System**: Comprehensive event emission for monitoring and logging
- **State Management**: Detailed tracking of all operations
- **Rollback Support**: Ability to undo copy operations

## Basic Usage

### Simple File Copy

```
resource {
  source "/path/to/source/file.txt"
  destination "/path/to/destination/file.txt"
  actions {
    copy {}
  }
}
```

### Directory Copy

```
resource {
  source "/path/to/source/directory"
  destination "/path/to/destination/directory"
  actions {
    copy {
      recursive true
    }
  }
}
```

## Advanced Features

### Selective Copying with Patterns

#### Include Patterns

Copy only specific file types:

```
resource {
  source "/path/to/source"
  destination "/path/to/destination"
  actions {
    copy {
      recursive true
      include "*.txt"
    }
  }
}
```

Copy multiple file types:

```
resource {
  source "/path/to/source"
  destination "/path/to/destination"
  actions {
    copy {
      recursive true
      include "*.txt,*.md,*.json"
    }
  }
}
```

#### Exclude Patterns

Skip specific file types:

```
resource {
  source "/path/to/source"
  destination "/path/to/destination"
  actions {
    copy {
      recursive true
      exclude "*.log,*.tmp"
    }
  }
}
```

#### Complex Patterns

Use wildcard patterns:

```
resource {
  source "/path/to/source"
  destination "/path/to/destination"
  actions {
    copy {
      recursive true
      include "test*"  # Matches test1.txt, test_file.log, etc.
    }
  }
}
```

### Conflict Resolution

#### Skip Existing Files

```
resource {
  source "/path/to/source"
  destination "/path/to/destination"
  actions {
    copy {
      conflict_resolution "skip"
    }
  }
}
```

#### Overwrite Existing Files

```
resource {
  source "/path/to/source"
  destination "/path/to/destination"
  actions {
    copy {
      conflict_resolution "overwrite"
    }
  }
}
```

#### Merge (Overwrite) Files

```
resource {
  source "/path/to/source"
  destination "/path/to/destination"
  actions {
    copy {
      conflict_resolution "merge"
    }
  }
}
```

### Progress Tracking

Enable progress tracking for large operations:

```
resource {
  source "/path/to/large/directory"
  destination "/path/to/destination"
  actions {
    copy {
      recursive true
      show_progress true
    }
  }
}
```

## Configuration Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `recursive` | boolean | `false` | Copy directories recursively |
| `include` | string/array | `[]` | Glob patterns for files to include |
| `exclude` | string/array | `[]` | Glob patterns for files to exclude |
| `conflict_resolution` | string | `skip` | How to handle existing files (`skip`, `overwrite`, `merge`) |
| `show_progress` | boolean | `true` | Enable progress tracking and events |

## Pattern Matching

The copy module uses glob patterns for file selection. Supported patterns include:

- `*` - Matches any characters
- `?` - Matches any single character
- `[abc]` - Matches any character in the set
- `[a-z]` - Matches any character in the range
- `**` - Matches any number of directories

### Pattern Examples

```
# Copy all text files
include "*.txt"

# Copy all files starting with 'test'
include "test*"

# Copy all files in subdirectories
include "**/*.txt"

# Copy specific file types
include "*.{txt,md,json}"

# Exclude temporary files
exclude "*.tmp,*.log,*.cache"
```

## State Tracking

The copy module tracks detailed state information:

### State Properties

| Property | Type | Description |
|----------|------|-------------|
| `copiedFiles` | int | Number of files successfully copied |
| `skippedFiles` | int | Number of files skipped (excluded or conflicts) |
| `overwrittenFiles` | int | Number of files that were overwritten |
| `totalFiles` | int | Total number of files processed |
| `includePatterns` | array | Active include patterns |
| `excludePatterns` | array | Active exclude patterns |
| `conflictResolution` | string | Active conflict resolution strategy |
| `showProgress` | boolean | Whether progress tracking is enabled |

## Examples

### Complete Configuration Example

```
resource {
  source "/home/user/documents"
  destination "/backup/documents"
  actions {
    copy {
      recursive true
      include "*.txt,*.md,*.pdf"
      exclude "*.tmp,*.cache"
      conflict_resolution "skip"
      show_progress true
    }
  }
}
```
