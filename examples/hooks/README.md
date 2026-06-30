# Hooks Example

This example demonstrates how to use **hooks** in configr to add logging, validation, and cleanup operations around your main actions.

## What are Hooks?

Hooks are special actions that run before or after your main operations. They allow you to:

- **Log operations** - Add informative messages before and after actions
- **Validate conditions** - Check prerequisites or verify results
- **Perform cleanup** - Clean up temporary files or resources
- **Run dependent commands** - Execute related operations
- **Create backups** - Backup files before modifications

## Hook Types

### Before Hooks
- Execute **before** the main action
- Useful for logging, validation, and preparation
- Run in the order they appear in the configuration

### After Hooks  
- Execute **after** the main action
- Useful for verification, cleanup, and follow-up operations
- Run in the order they appear in the configuration

## Examples in This Directory

### 1. File Copy with Logging (`copy-with-logging`)
```hcl
before {
  echo {
    message "Starting file copy operation"
    level "info"
  }
}

copy {
  overwrite true
  backup_original true
}

after {
  echo {
    message "File copy completed successfully"
    level "info"
  }
}
```

### 2. Download with Validation (`download-with-validation`)
```hcl
before {
  echo {
    message "Checking if download destination exists"
    level "info"
  }
}

download {
  timeout 30
  retry_count 3
}

after {
  validate {
    file_path "downloaded_data.json"
    schema_type "json"
    required_fields ["slideshow", "slides"]
  }
}
```

### 3. Template with Backup (`template-with-backup`)
```hcl
before {
  backup {
    source "generated_config.conf"
    destination "backups/config_backup_$(date +%Y%m%d_%H%M%S).conf"
    create_destination true
  }
}

template {
  app_name "MyApplication"
  version "1.0.0"
  debug false
  port 8080
  host "localhost"
}

after {
  echo {
    message "Template processed, restarting service"
    level "info"
  }
  execute {
    command "systemctl reload myapp"
    on_success true
    timeout 10
  }
}
```

### 4. Package Installation with System Checks (`package-with-checks`)
```hcl
before {
  echo {
    message "Checking system requirements before package installation"
    level "info"
  }
  execute {
    command "df -h /"
    on_success true
  }
}

package {
  packages ["curl", "wget", "git"]
  manager "auto"
  update_cache true
  skip_installed true
}

after {
  echo {
    message "Package installation completed, verifying..."
    level "info"
  }
  execute {
    command "which curl wget git"
    on_success true
  }
}
```

### 5. Complex Workflow (`complex-workflow`)
Shows multiple before and after hooks working together in a complex deployment scenario.

## Running the Example

1. Navigate to this directory:
   ```bash
   cd examples/hooks
   ```

2. Run configr to execute the hooks example:
   ```bash
   configr apply config
   ```

3. Observe the output - you'll see:
   - Before hook messages
   - Main action execution
   - After hook messages
   - All operations logged with timestamps

## Expected Output

When you run this example, you should see output like:

```
[INFO] Starting file copy operation
[INFO] Copying source_file.txt to destination_file.txt
[INFO] File copy completed successfully

[INFO] Checking if download destination exists
[INFO] Downloading https://httpbin.org/json to downloaded_data.json
[INFO] Validating downloaded file...

[INFO] Creating backup of existing config...
[INFO] Processing template config.template
[INFO] Template processed, restarting service

[INFO] Checking system requirements before package installation
[INFO] Installing packages: curl, wget, git
[INFO] Package installation completed, verifying...

[INFO] Starting complex deployment workflow
[INFO] Creating destination directory...
[INFO] Copying files...
[INFO] Setting permissions...
[INFO] Deployment completed, running post-deployment checks
[INFO] Complex workflow completed successfully
```

## Hook Execution Order

### Normal Execution
1. All `before` hooks (in order)
2. Main action(s)
3. All `after` hooks (in order)

### Rollback Execution (if errors occur)
1. All `after` hooks (in reverse order)
2. Main action rollback
3. All `before` hooks (in reverse order)

## Best Practices

### Use Before Hooks For:
- **Logging** - Inform users what's about to happen
- **Validation** - Check prerequisites and system state
- **Preparation** - Create directories, backup files
- **Dependency checks** - Verify required tools are available

### Use After Hooks For:
- **Verification** - Confirm operations completed successfully
- **Cleanup** - Remove temporary files
- **Follow-up actions** - Restart services, send notifications
- **Status reporting** - Log completion status

### Hook Design Tips:
- Keep hooks **focused** - Each hook should have a single purpose
- Make hooks **idempotent** - Safe to run multiple times
- Use **descriptive messages** - Help users understand what's happening
- **Handle failures gracefully** - Don't let hook failures break the main operation

## Common Hook Patterns

### Logging Pattern
```hcl
before {
  echo {
    message "Starting [operation name]"
    level "info"
  }
}

# main action

after {
  echo {
    message "[Operation name] completed successfully"
    level "info"
  }
}
```

### Validation Pattern
```hcl
before {
  validate {
    file_path "required_file.txt"
    exists true
  }
}

# main action

after {
  validate {
    file_path "output_file.txt"
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

## Rollback

To rollback the hooks example:

```bash
configr rollback config
```

This will:
1. Rollback all `after` hooks (in reverse order)
2. Rollback the main actions
3. Rollback all `before` hooks (in reverse order)

## Troubleshooting

### Hook Execution Issues
- Check that hook actions are valid and properly configured
- Ensure any commands in `execute` hooks exist and are accessible
- Verify file paths in hooks are correct

### Common Errors
- **"Unknown action type"** - Make sure hook action types are supported
- **"Command not found"** - Verify commands in execute hooks are available
- **"File not found"** - Check file paths in validation or backup hooks

### Debug Tips
- Use `echo` hooks with `verbose: true` for detailed logging
- Add `level: "debug"` to see more detailed information
- Check the lockfile for state information about hook execution
