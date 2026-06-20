# Configr Rollback System

Configr provides comprehensive rollback capabilities that allow you to undo any configuration changes safely and reliably.

## Overview

The rollback system is built on three core principles:

1. **State Tracking**: All operations save their state to the lockfile
2. **Atomic Rollback**: Operations are rolled back in reverse order
3. **Safety First**: Rollback operations are validated and safe

## How Rollback Works

### State Persistence

Every operation in Configr automatically saves its state to the lockfile:

```json
{
  "id": "file_1",
  "type": "file",
  "status": "completed",
  "state": {
    "operation": "create",
    "filePath": "/path/to/file.txt",
    "originalContent": null,
    "backupPath": null,
    "fileExisted": false,
    "operationSuccess": true
  }
}
```

### Rollback Process

1. **Load Lockfile**: Read the lockfile to get completed operations
2. **Restore State**: Restore state from lockfile to actions
3. **Create Modules**: Create modules with restored state
4. **Execute Rollback**: Run rollback operations in reverse order
5. **Update Status**: Mark operations as rolled back

## Rollback Commands

### Rollback All Operations

```bash
dart run bin/main.dart rollback
```

This rolls back all completed operations in reverse order.

### Rollback Specific Number of Operations

```bash
# Rollback the last operation
dart run bin/main.dart rollback -n 1

# Rollback the last 3 operations
dart run bin/main.dart rollback -n 3
```

### Rollback with Custom Config

```bash
dart run bin/main.dart rollback -c my-config.config
```

## Module-Specific Rollback Behavior

### File Module

#### Create Operation Rollback
- **Behavior**: Removes files that were created
- **State**: Tracks `fileExisted: false` for new files
- **Safety**: Only removes files that were created by the operation

#### Edit Operation Rollback
- **Behavior**: Restores original content from backup
- **State**: Tracks `originalContent` and `backupPath`
- **Safety**: Validates backup exists before restoration

#### Remove Operation Rollback
- **Behavior**: Restores removed files from backup
- **State**: Tracks `originalContent` and `backupPath`
- **Safety**: Validates backup exists before restoration

### Git Module

#### Clone Operation Rollback
- **Behavior**: Removes cloned directories
- **State**: Tracks repository URL and local path
- **Safety**: Only removes directories that were created by the operation

#### Pull Operation Rollback
- **Behavior**: Resets to previous commit
- **State**: Tracks previous commit hash
- **Safety**: Validates git repository state

#### Commit Operation Rollback
- **Behavior**: Reverts the commit
- **State**: Tracks commit hash and changes
- **Safety**: Validates commit exists before reverting

### Network Module

#### Ping Operation Rollback
- **Behavior**: No rollback needed (read-only operation)
- **State**: Tracks operation results
- **Safety**: Read-only operations are safe

## Rollback Safety Features

### Atomic Operations
- Rollback operations are atomic - either complete or fail cleanly
- No partial rollbacks that leave the system in an inconsistent state

### State Validation
- All rollback operations validate state before attempting restoration
- Invalid or missing state prevents rollback execution

### Error Recovery
- Failed rollbacks provide detailed error messages
- System remains in a consistent state even if rollback fails

### Backup Verification
- Backup files are verified before restoration
- Missing or corrupted backups prevent rollback

## Rollback Examples

### Basic File Operations

```bash
# Apply configuration
dart run bin/main.dart apply

# Rollback all changes
dart run bin/main.dart rollback
```

### Selective Rollback

```bash
# Apply configuration with multiple operations
dart run bin/main.dart apply

# Rollback only the last operation
dart run bin/main.dart rollback -n 1

# Rollback the last 3 operations
dart run bin/main.dart rollback -n 3
```

### Git Operations

```bash
# Clone repository and create files
dart run bin/main.dart apply

# Rollback file creation but keep repository
dart run bin/main.dart rollback -n 2

# Rollback everything including repository clone
dart run bin/main.dart rollback
```

## Rollback Best Practices

### 1. Test Rollback Before Production
Always test rollback functionality in a safe environment before using in production.

### 2. Use Selective Rollback
Use `-n` parameter to rollback specific operations instead of everything.

### 3. Monitor Rollback Operations
Watch rollback output to ensure operations complete successfully.

### 4. Backup Important Data
Even though Configr provides rollback, always backup critical data separately.

### 5. Understand Module Behavior
Each module has specific rollback behavior - understand what will happen before rolling back.

## Troubleshooting Rollback

### Common Issues

#### "No rollback information available"
- **Cause**: No previous operations have been applied
- **Solution**: Apply configuration first, then rollback

#### "Operation was not successful, skipping rollback"
- **Cause**: The original operation failed
- **Solution**: Check the original operation logs for errors

#### "Backup file not found"
- **Cause**: Backup file was deleted or moved
- **Solution**: Check if backup files exist, may need manual restoration

#### "State validation failed"
- **Cause**: Lockfile state is corrupted or invalid
- **Solution**: Check lockfile integrity, may need to reapply configuration

### Debug Rollback

Enable verbose logging to see detailed rollback information:

```bash
dart run bin/main.dart rollback --verbose
```

### Manual Rollback

If automatic rollback fails, you can manually restore from backup files:

1. Check for `.backup` files in the target directories
2. Restore files from backup manually
3. Clean up any created files
4. Update lockfile status if needed

## Rollback Limitations

### Read-Only Operations
Some operations (like network ping) are read-only and don't need rollback.

### External Dependencies
Rollback may not work if external dependencies (like git repositories) are unavailable.

### File System Changes
Rollback cannot undo file system changes made outside of Configr.

### Network Operations
Network operations may not be fully reversible if external systems have changed.

## Integration with Other Systems

### CI/CD Pipelines
Rollback can be integrated into CI/CD pipelines for automated recovery:

```yaml
- name: Apply Configuration
  run: dart run bin/main.dart apply

- name: Rollback on Failure
  if: failure()
  run: dart run bin/main.dart rollback
```

### Monitoring Systems
Monitor rollback operations and alert on failures:

```bash
# Check rollback status
dart run bin/main.dart status

# Monitor for rollback failures
dart run bin/main.dart rollback 2>&1 | grep -i error
```

### Backup Systems
Integrate with external backup systems for additional safety:

```bash
# Create backup before applying
tar -czf backup-$(date +%Y%m%d).tar.gz /path/to/config

# Apply configuration
dart run bin/main.dart apply

# Rollback if needed
dart run bin/main.dart rollback
```
