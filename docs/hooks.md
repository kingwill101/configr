# Hooks Documentation

Hooks are a powerful feature in configr that allow you to execute actions before and after your main operations. They provide a way to add logging, validation, cleanup, and other supporting operations around your primary actions.

## Table of Contents

- [Overview](#overview)
- [Hook Types](#hook-types)
- [Configuration Syntax](#configuration-syntax)
- [Execution Order](#execution-order)
- [Use Cases](#use-cases)
- [Best Practices](#best-practices)
- [Common Patterns](#common-patterns)
- [Error Handling](#error-handling)
- [Rollback Behavior](#rollback-behavior)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)

## Overview

Hooks in configr are special actions that run in a specific order around your main operations:

- **Before hooks** - Execute before the main action
- **After hooks** - Execute after the main action

This allows you to create robust workflows with proper logging, validation, and cleanup.

## Hook Types

### Before Hooks

Before hooks execute **before** your main action and are useful for:

- **Logging** - Inform users about upcoming operations
- **Validation** - Check prerequisites and system state
- **Preparation** - Create directories, backup files, stop services
- **Dependency checks** - Verify required tools or files exist

### After Hooks

After hooks execute **after** your main action and are useful for:

- **Verification** - Confirm operations completed successfully
- **Cleanup** - Remove temporary files or resources
- **Follow-up actions** - Restart services, send notifications
- **Status reporting** - Log completion status and results

## Configuration Syntax

Hooks are configured within the `actions` block of a resource:

```hcl
resource {
  id "example-with-hooks"
  source "/path/to/source"
  destination "/path/to/destination"
  
  actions {
    # Before hook
    before {
      echo {
        message "Starting operation"
        level "info"
      }
    }
    
    # Main action
    copy {
      overwrite true
    }
    
    # After hook
    after {
      echo {
        message "Operation completed"
        level "info"
      }
    }
  }
}
```

### Multiple Hooks

You can have multiple hooks of the same type:

```hcl
actions {
  # Multiple before hooks
  before {
    echo {
      message "Step 1: Checking prerequisites"
      level "info"
    }
  }
  
  before {
    execute {
      command "mkdir -p /tmp/backup"
      on_success true
    }
  }
  
  # Main action
  copy {
    source "config.conf"
    destination "/etc/config.conf"
  }
  
  # Multiple after hooks
  after {
    echo {
      message "Step 1: Verifying installation"
      level "info"
    }
  }
  
  after {
    execute {
      command "systemctl reload myapp"
      on_success true
    }
  }
}
```

## Execution Order

### Normal Execution

1. All `before` hooks execute in the order they appear
2. Main action(s) execute
3. All `after` hooks execute in the order they appear

### Rollback Execution

If an error occurs during execution, rollback happens in reverse order:

1. All `after` hooks rollback in reverse order
2. Main action(s) rollback
3. All `before` hooks rollback in reverse order

## Use Cases

### 1. Logging and Monitoring

Add comprehensive logging around operations:

```hcl
actions {
  before {
    echo {
      message "Starting database backup"
      level "info"
      color true
    }
  }
  
  backup {
    source "/var/lib/mysql"
    destination "/backup/mysql_$(date +%Y%m%d)"
  }
  
  after {
    echo {
      message "Database backup completed successfully"
      level "success"
      color true
    }
  }
}
```

### 2. Validation and Verification

Validate prerequisites and results:

```hcl
actions {
  before {
    validate {
      file_path "/etc/ssl/certs/cert.pem"
      exists true
    }
  }
  
  copy {
    source "/etc/ssl/certs/cert.pem"
    destination "/app/certs/cert.pem"
  }
  
  after {
    validate {
      file_path "/app/certs/cert.pem"
      schema_type "pem"
    }
  }
}
```

### 3. Service Management

Stop and start services around operations:

```hcl
actions {
  before {
    execute {
      command "systemctl stop nginx"
      on_success true
    }
  }
  
  copy {
    source "nginx.conf"
    destination "/etc/nginx/nginx.conf"
  }
  
  after {
    execute {
      command "nginx -t"
      on_success true
    }
  }
  
  after {
    execute {
      command "systemctl start nginx"
      on_success true
    }
  }
}
```

### 4. Backup and Recovery

Create backups before modifications:

```hcl
actions {
  before {
    backup {
      source "/etc/nginx/nginx.conf"
      destination "/backup/nginx_$(date +%Y%m%d_%H%M%S).conf"
      create_destination true
    }
  }
  
  template {
    source "nginx.conf.template"
    destination "/etc/nginx/nginx.conf"
    variables {
      server_name "example.com"
      ssl_enabled true
    }
  }
  
  after {
    echo {
      message "Configuration updated, backup created"
      level "info"
    }
  }
}
```

### 5. Cleanup Operations

Clean up temporary files and resources:

```hcl
actions {
  before {
    echo {
      message "Creating temporary workspace"
      level "info"
    }
  }
  
  execute {
    command "mkdir -p /tmp/build"
    on_success true
  }
  
  copy {
    source "build_files"
    destination "/tmp/build"
    recursive true
  }
  
  after {
    execute {
      command "rm -rf /tmp/build"
      on_success true
    }
  }
  
  after {
    echo {
      message "Temporary files cleaned up"
      level "info"
    }
  }
}
```

## Best Practices

### 1. Keep Hooks Focused

Each hook should have a single, clear purpose:

```hcl
# Good - focused hooks
before {
  echo {
    message "Starting operation"
    level "info"
  }
}

before {
  validate {
    file_path "required_file.txt"
    exists true
  }
}

# Avoid - mixed concerns in one hook
before {
  echo {
    message "Starting operation"
    level "info"
  }
  validate {
    file_path "required_file.txt"
    exists true
  }
  execute {
    command "mkdir -p /tmp"
    on_success true
  }
}
```

### 2. Make Hooks Idempotent

Hooks should be safe to run multiple times:

```hcl
# Good - idempotent
before {
  execute {
    command "mkdir -p /var/log/myapp"
    on_success true
  }
}

# Avoid - not idempotent
before {
  execute {
    command "mkdir /var/log/myapp"
    on_success true
  }
}
```

### 3. Use Descriptive Messages

Provide clear, informative messages:

```hcl
# Good - descriptive
before {
  echo {
    message "Backing up existing configuration before update"
    level "info"
  }
}

# Avoid - vague
before {
  echo {
    message "Starting"
    level "info"
  }
}
```

### 4. Handle Failures Gracefully

Use appropriate error handling:

```hcl
before {
  execute {
    command "systemctl stop myservice"
    on_success true  # Don't fail if service is already stopped
  }
}
```

### 5. Consider Performance

Avoid expensive operations in hooks unless necessary:

```hcl
# Good - lightweight validation
before {
  validate {
    file_path "config.conf"
    exists true
  }
}

# Avoid - expensive operation in hook
before {
  execute {
    command "find / -name '*.conf' -exec grep -l 'pattern' {} \\;"
    on_success true
  }
}
```

## Common Patterns

### Logging Pattern

```hcl
before {
  echo {
    message "Starting [operation name]"
    level "info"
    color true
  }
}

# main action

after {
  echo {
    message "[Operation name] completed successfully"
    level "success"
    color true
  }
}
```

### Validation Pattern

```hcl
before {
  validate {
    file_path "input_file.txt"
    exists true
    readable true
  }
}

# main action

after {
  validate {
    file_path "output_file.txt"
    exists true
    schema_type "json"
  }
}
```

### Backup Pattern

```hcl
before {
  backup {
    source "config.conf"
    destination "backups/config_$(date +%Y%m%d_%H%M%S).conf"
    create_destination true
  }
}

# main action that modifies config.conf
```

### Service Management Pattern

```hcl
before {
  execute {
    command "systemctl stop myservice"
    on_success true
  }
}

# main action

after {
  execute {
    command "systemctl start myservice"
    on_success true
  }
}
```

### Cleanup Pattern

```hcl
before {
  execute {
    command "mkdir -p /tmp/workdir"
    on_success true
  }
}

# main action using /tmp/workdir

after {
  execute {
    command "rm -rf /tmp/workdir"
    on_success true
  }
}
```

## Error Handling

### Hook Failure Behavior

- If a **before hook** fails, the main action is not executed
- If the **main action** fails, after hooks are not executed
- If an **after hook** fails, it doesn't affect the main action result

### Error Recovery

```hcl
actions {
  before {
    execute {
      command "backup_database.sh"
      on_success true  # Don't fail if backup already exists
    }
  }
  
  copy {
    source "new_config.conf"
    destination "/etc/app/config.conf"
  }
  
  after {
    execute {
      command "restart_service.sh"
      on_success true  # Don't fail if service restart fails
    }
  }
}
```

## Rollback Behavior

When rollback occurs, hooks are executed in reverse order:

### Normal Rollback Order

1. `after` hooks (in reverse order)
2. Main action rollback
3. `before` hooks (in reverse order)

### Example Rollback Scenario

```hcl
actions {
  before {
    execute {
      command "systemctl stop nginx"
    }
  }
  
  copy {
    source "nginx.conf"
    destination "/etc/nginx/nginx.conf"
  }
  
  after {
    execute {
      command "systemctl start nginx"
    }
  }
}
```

If the copy fails, rollback will:
1. Try to stop nginx (reverse of after hook)
2. Restore the original nginx.conf (main action rollback)
3. Try to start nginx (reverse of before hook)

## Examples

### Complete Example: Application Deployment

```hcl
resource {
  id "app-deployment"
  source "app_files"
  destination "/opt/myapp"
  
  actions {
    # Pre-deployment checks
    before {
      echo {
        message "Starting application deployment"
        level "info"
        color true
      }
    }
    
    before {
      execute {
        command "df -h /opt"
        on_success true
      }
    }
    
    before {
      execute {
        command "systemctl stop myapp"
        on_success true
      }
    }
    
    before {
      backup {
        source "/opt/myapp"
        destination "/backup/myapp_$(date +%Y%m%d_%H%M%S)"
        create_destination true
      }
    }
    
    # Main deployment
    copy {
      source "app_files"
      destination "/opt/myapp"
      overwrite true
      recursive true
    }
    
    permissions {
      path "/opt/myapp"
      mode "755"
      recursive true
    }
    
    # Post-deployment
    after {
      execute {
        command "systemctl start myapp"
        on_success true
      }
    }
    
    after {
      execute {
        command "systemctl status myapp"
        on_success true
      }
    }
    
    after {
      echo {
        message "Application deployment completed successfully"
        level "success"
        color true
      }
    }
  }
}
```

## Troubleshooting

### Common Issues

#### Hook Not Executing

**Problem**: Hooks are not running

**Solutions**:
- Check that hooks are properly nested within the `actions` block
- Verify hook syntax is correct
- Ensure the main action is valid

#### Hook Execution Order Issues

**Problem**: Hooks are running in unexpected order

**Solutions**:
- Remember: `before` hooks run first, then main action, then `after` hooks
- Multiple hooks of the same type run in the order they appear
- Check for typos in hook type names (`before` vs `after`)

#### Hook Failures Breaking Main Action

**Problem**: Hook failure prevents main action from running

**Solutions**:
- Use `on_success true` for optional operations
- Make hooks idempotent
- Handle expected failures gracefully

### Debug Tips

1. **Add verbose logging**:
   ```hcl
   before {
     echo {
       message "Debug: About to execute main action"
       level "debug"
       verbose true
     }
   }
   ```

2. **Use dry-run mode**:
   ```bash
   configr apply config --dry-run
   ```

3. **Check lockfile for state**:
   ```bash
   cat lockfile.json
   ```

4. **Enable debug logging**:
   ```bash
   configr apply config --verbose
   ```

### Performance Considerations

- Keep hooks lightweight and fast
- Avoid expensive operations in hooks
- Use hooks for essential operations only
- Consider the impact of multiple hooks on execution time

## Related Documentation

- [Echo Module](echo.md) - For logging in hooks
- [Execute Module](execute.md) - For running commands in hooks
- [Validate Module](validate.md) - For validation in hooks
- [Backup Module](backup.md) - For backup operations in hooks
- [Rollback Guide](rollback.md) - Understanding rollback behavior
