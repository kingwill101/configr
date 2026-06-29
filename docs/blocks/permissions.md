# Permissions Module

Enhanced file and directory permissions management with recursive operations, ACL support, and advanced permission modes.

## Features

- **Recursive Operations**: Apply permissions to directories and all their contents
- **Access Control Lists (ACL)**: Support for advanced permission management
- **Permission Modes**: Support for both octal and symbolic permission formats
- **Symlink Handling**: Control whether to follow symbolic links
- **Progress Tracking**: Monitor large directory operations
- **Comprehensive Rollback**: Restore original permissions and ownership
- **Event System**: Real-time progress and status updates

## Basic Usage

### Simple File Permissions

```
resource {
  source "/path/to/file.txt"
  destination "/path/to/file.txt"
  actions {
    permissions {
      mode "644"
    }
  }
}
```

### File Ownership

```
resource {
  source "/path/to/file.txt"
  destination "/path/to/file.txt"
  actions {
    permissions {
      owner "username"
      group "groupname"
    }
  }
}
```

### Combined Permissions and Ownership

```
resource {
  source "/path/to/file.txt"
  destination "/path/to/file.txt"
  actions {
    permissions {
      owner "username"
      group "groupname"
      mode "755"
    }
  }
}
```

## Advanced Features

### Recursive Directory Permissions

```
resource {
  source "/path/to/directory"
  destination "/path/to/directory"
  actions {
    permissions {
      mode "755"
      recursive true
    }
  }
}
```

### Symbolic Permission Mode

```
resource {
  source "/path/to/file.txt"
  destination "/path/to/file.txt"
  actions {
    permissions {
      mode "u+rw,g+r,o+r"
    }
  }
}
```

### ACL Support

```
resource {
  source "/path/to/file.txt"
  destination "/path/to/file.txt"
  actions {
    permissions {
      mode "644"
      use_acl true
      acl_entries "user:username:rwx,group:groupname:rx"
    }
  }
}
```

### Symlink Handling

```
resource {
  source "/path/to/directory"
  destination "/path/to/directory"
  actions {
    permissions {
      mode "755"
      recursive true
      follow_symlinks true
    }
  }
}
```


### Complex Configuration

```
resource {
  source "/path/to/directory"
  destination "/path/to/directory"
  actions {
    permissions {
      owner "webuser"
      group "webgroup"
      mode "755"
      recursive true
      use_acl true
      acl_entries "user:admin:rwx,group:developers:rx"
      follow_symlinks false
    }
  }
}
```

## Configuration Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `owner` | string | `null` | File/directory owner |
| `group` | string | `null` | File/directory group |
| `mode` | string | **required** | Permission mode (octal or symbolic) |
| `recursive` | boolean | `false` | Apply permissions recursively to directories |
| `use_acl` | boolean | `false` | Enable Access Control List support |
| `acl_entries` | string | `null` | ACL entries to apply |
| `follow_symlinks` | boolean | `false` | Follow symbolic links during recursive operations |

## Permission Modes

### Octal Mode (Default)

```
# Standard octal permissions
mode "755"  # rwxr-xr-x
mode "644"  # rw-r--r--
mode "600"  # rw-------
mode "777"  # rwxrwxrwx
```

### Symbolic Mode

```
# Symbolic permissions
mode "u+rw,g+r,o+r"     # Add read/write for user, read for group/other
mode "u=rwx,g=rx,o=r"   # Set specific permissions
mode "a+x"              # Add execute for all (user, group, other)
mode "g-w,o-r"          # Remove write from group, read from other
```

## ACL Entries Format

ACL entries follow the standard format:

```
# User ACL
user:username:permissions

# Group ACL  
group:groupname:permissions

# Multiple entries (comma-separated)
user:admin:rwx,group:developers:rx,other:r
```

### ACL Permission Characters

- `r` - Read permission
- `w` - Write permission  
- `x` - Execute permission
- `-` - No permission

## State Tracking

The permissions module tracks detailed state information:

### State Properties

| Property | Type | Description |
|----------|------|-------------|
| `owner` | string | Target owner |
| `group` | string | Target group |
| `mode` | string | Target permission mode |
| `recursive` | boolean | Whether recursive mode is enabled |
| `useAcl` | boolean | Whether ACL support is enabled |
| `aclEntries` | string | ACL entries to apply |
| `followSymlinks` | boolean | Whether to follow symbolic links |
| `processedFiles` | int | Number of files successfully processed |
| `totalFiles` | int | Total number of files found |
| `failedFiles` | int | Number of files that failed processing |
| `originalStates` | array | Original permission states for rollback |

## Examples

### Web Server Directory Setup

```
resource {
  source "/var/www/html"
  destination "/var/www/html"
  actions {
    permissions {
      owner "www-data"
      group "www-data"
      mode "755"
      recursive true
      follow_symlinks false
    }
  }
}
```

### Secure Configuration Files

```
resource {
  source "/etc/myapp"
  destination "/etc/myapp"
  actions {
    permissions {
      owner "root"
      group "myapp"
      mode "640"
      recursive true
      use_acl true
      acl_entries "user:admin:rw,group:myapp:r"
    }
  }
}
```

### Development Environment

```
resource {
  source "/home/developer/project"
  destination "/home/developer/project"
  actions {
    permissions {
      owner "developer"
      group "developers"
      mode "755"
      recursive true
      follow_symlinks true
    }
  }
}
```

### Backup Directory Security

```
resource {
  source "/backup/sensitive"
  destination "/backup/sensitive"
  actions {
    permissions {
      owner "backup"
      group "backup"
      mode "700"
      recursive true
      use_acl true
      acl_entries "user:admin:rwx"
    }
  }
}
```

### Log Directory Permissions

```
resource {
  source "/var/log/myapp"
  destination "/var/log/myapp"
  actions {
    permissions {
      owner "myapp"
      group "adm"
      mode "755"
      recursive true
      use_acl true
      acl_entries "group:adm:r,other:r"
    }
  }
}
```

### Temporary Directory Cleanup

```
resource {
  source "/tmp/myapp"
  destination "/tmp/myapp"
  actions {
    permissions {
      owner "myapp"
      group "myapp"
      mode "1777"
      recursive true
    }
  }
}
```

## Error Handling

The permissions module provides comprehensive error handling:

- **Source Not Found**: Throws `SourceNotFoundException` if the target doesn't exist
- **Permission Denied**: Handles insufficient privileges gracefully
- **ACL Errors**: Reports ACL-specific errors with detailed messages
- **Rollback Failures**: Logs rollback issues without stopping execution
- **Partial Failures**: Continues processing other files if some fail

## Rollback Support

The module automatically tracks original permissions and ownership for rollback:

- **Single Files**: Restores original permissions and ownership
- **Recursive Operations**: Restores all files to their original state
- **ACL Entries**: Removes applied ACL entries (platform-dependent)
- **Error Recovery**: Continues rollback even if some files fail

## Performance Considerations

- **Large Directories**: Progress tracking helps monitor long-running operations
- **Symlink Handling**: Disable `follow_symlinks` for better performance
- **ACL Operations**: ACL changes may be slower than standard permissions
- **Extended Attributes**: Extended attribute operations are not currently implemented
- **Batch Processing**: Processes files individually for better error isolation