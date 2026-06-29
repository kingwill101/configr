# Sync Module

The sync module provides advanced file synchronization capabilities between local and remote locations with support for bidirectional synchronization, conflict resolution, and bandwidth management.

## Features

- **Bidirectional Synchronization**: Sync files in both directions between source and destination
- **Conflict Resolution**: Multiple strategies for handling file conflicts
- **Pattern Filtering**: Include/exclude files based on patterns
- **Orphan Management**: Option to delete files that don't exist in source
- **Attribute Preservation**: Preserve file permissions and timestamps
- **Bandwidth Limiting**: Control sync speed (placeholder for future implementation)
- **Comprehensive Statistics**: Track files processed, conflicts resolved, and errors

## Configuration

### Basic Sync Configuration

```configr
resources {
  resource {
    id "sync-config"
    source "/path/to/source"
    destination "/path/to/destination"
    
    actions {
      sync {
        sync_mode "bidirectional"
        conflict_resolution "newer"
        preserve_permissions true
        preserve_timestamps true
        delete_orphans false
      }
    }
  }
}
```

### Advanced Sync Configuration

```configr
resources {
  resource {
    id "advanced-sync"
    source "/home/user/documents"
    destination "/backup/documents"
    
    actions {
      sync {
        sync_mode "source_to_dest"
        conflict_resolution "source"
        bandwidth_limit 1024
        preserve_permissions true
        preserve_timestamps true
        delete_orphans true
        exclude_patterns ["*.tmp", "*.log", ".DS_Store"]
        include_patterns ["*.txt", "*.md", "*.pdf"]
      }
    }
  }
}
```

## Configuration Options

### Sync Mode

Controls the direction of synchronization:

- `bidirectional` (default): Sync files in both directions
- `source_to_dest`: Only sync from source to destination
- `dest_to_source`: Only sync from destination to source

### Conflict Resolution

Determines how to handle files that exist in both locations:

- `newer` (default): Use the file with the most recent modification time
- `source`: Always use the source file
- `destination`: Always use the destination file
- `larger`: Use the file with the larger size
- `skip`: Skip conflicting files

### File Filtering

#### Exclude Patterns
List of patterns to exclude from synchronization:
```configr
exclude_patterns ["*.tmp", "*.log", ".DS_Store", "node_modules"]
```

#### Include Patterns
List of patterns to include in synchronization (if specified, only matching files are synced):
```configr
include_patterns ["*.txt", "*.md", "*.pdf"]
```

### Other Options

- `bandwidth_limit`: Maximum bandwidth in KB/s (0 = no limit, placeholder for future implementation)
- `preserve_permissions`: Preserve file permissions (default: true)
- `preserve_timestamps`: Preserve file modification and access times (default: true)
- `delete_orphans`: Delete files in destination that don't exist in source (default: false)

## Examples

### Document Backup

```configr
resources {
  resource {
    id "document-backup"
    source "/home/user/Documents"
    destination "/backup/documents"
    
    actions {
      sync {
        sync_mode "source_to_dest"
        conflict_resolution "newer"
        exclude_patterns ["*.tmp", "*.swp", ".DS_Store"]
        preserve_permissions true
        preserve_timestamps true
      }
    }
  }
}
```

### Bidirectional Project Sync

```configr
resources {
  resource {
    id "project-sync"
    source "/home/user/projects/myapp"
    destination "/shared/projects/myapp"
    
    actions {
      sync {
        sync_mode "bidirectional"
        conflict_resolution "newer"
        include_patterns ["*.dart", "*.yaml", "*.md", "pubspec.*"]
        exclude_patterns ["*.log", "build/", ".dart_tool/"]
        delete_orphans false
      }
    }
  }
}
```

### Selective File Sync

```configr
resources {
  resource {
    id "config-sync"
    source "/etc/myapp"
    destination "/backup/configs"
    
    actions {
      sync {
        sync_mode "source_to_dest"
        conflict_resolution "source"
        include_patterns ["*.conf", "*.cfg", "*.ini"]
        preserve_permissions true
        preserve_timestamps true
        delete_orphans true
      }
    }
  }
}
```

### Media Library Sync

```configr
resources {
  resource {
    id "media-sync"
    source "/media/photos"
    destination "/backup/photos"
    
    actions {
      sync {
        sync_mode "source_to_dest"
        conflict_resolution "newer"
        include_patterns ["*.jpg", "*.jpeg", "*.png", "*.gif", "*.mp4", "*.mov"]
        preserve_permissions false
        preserve_timestamps true
        delete_orphans false
      }
    }
  }
}
```

## Error Handling

The sync module provides comprehensive error handling:

- **Missing Paths**: Validates that source and destination paths exist
- **Permission Errors**: Logs permission issues and continues with other files
- **Conflict Resolution**: Handles conflicts based on configured strategy
- **Pattern Matching**: Gracefully handles invalid patterns
- **Statistics Tracking**: Tracks errors encountered during sync

## Rollback Considerations

**Important**: The sync module has limited rollback capabilities because it doesn't track the original state of files before synchronization. The rollback operation will:

- Log the sync results for manual review
- Provide information about what was changed
- Not automatically restore original file states

For critical operations, consider:
- Creating backups before sync operations
- Using version control systems
- Implementing your own backup strategy

## Performance Considerations

- **Large Directories**: Sync operations on large directories may take time
- **Network Paths**: Remote destinations may be slower than local operations
- **Pattern Matching**: Complex include/exclude patterns may impact performance
- **File Attributes**: Preserving permissions and timestamps adds overhead

## Best Practices

1. **Test First**: Always test sync operations on small directories first
2. **Backup Important Data**: Create backups before major sync operations
3. **Use Appropriate Conflict Resolution**: Choose the right strategy for your use case
4. **Monitor Results**: Check sync statistics and logs for any issues
5. **Pattern Efficiency**: Use specific patterns to avoid unnecessary file processing
6. **Permissions**: Be aware of permission requirements for source and destination paths

## Limitations

- **Network Sync**: Currently supports local file system operations only
- **Bandwidth Limiting**: Placeholder for future implementation
- **Advanced Permissions**: Limited permission preservation on some systems
- **Rollback**: Cannot fully restore original file states
- **Real-time Sync**: One-time operation, not continuous monitoring

## Troubleshooting

### Common Issues

1. **Permission Denied**
   - Ensure read access to source paths
   - Ensure write access to destination paths
   - Check file ownership and permissions

2. **Sync Not Working**
   - Verify source and destination paths exist
   - Check include/exclude patterns
   - Review sync mode configuration

3. **Unexpected File Deletions**
   - Check `delete_orphans` setting
   - Verify include/exclude patterns
   - Review conflict resolution strategy

4. **Performance Issues**
   - Use more specific include patterns
   - Consider syncing smaller directories
   - Check disk space and I/O performance

### Debug Information

The sync module provides detailed logging and statistics:
- Files processed count
- Conflicts resolved count
- Errors encountered count
- Sync results with file paths and operations
- Detailed error messages in logs

