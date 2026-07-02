# Execute Module

Enhanced command execution with environment management, timeouts, and process monitoring. Cross-platform execution with PowerShell support on Windows.

## Features

- **Environment Management**: Custom environment variables and inheritance control
- **Timeout Support**: Configurable execution timeouts with process killing
- **Process Monitoring**: Real-time process tracking and resource management
- **Input/Output Handling**: Stream input to commands and manage output size limits
- **Working Directory**: Execute commands in custom working directories
- **Event System**: Comprehensive event emission for monitoring and logging
- **Execution Validation**: Result validation and error handling

## Cross-Platform Execution

Configr automatically selects the appropriate shell for the target platform:

- **Linux/macOS/FreeBSD**: Uses `sh` by default, configurable to `bash`
- **Windows**: Uses PowerShell by default

PowerShell commands are encoded to avoid quoting issues. Commands execute through Configr's Execution Service, which handles platform-specific process invocation, output capture, and audit logging.

## Platform Support

| Feature | Linux | macOS | FreeBSD | Windows |
|---------|-------|-------|---------|---------|
| sh commands | Yes | Yes | Yes | No |
| PowerShell | No | No | No | Yes |
| Environment variables | Yes | Yes | Yes | Yes |
| Timeouts | Yes | Yes | Yes | Yes |
| Stdio redirection | Yes | Yes | Yes | Yes |

## Basic Usage

### Simple Command Execution

```
resource {
  source "/path/to/script"
  destination "/path/to/output"
  actions {
    execute {
      command "echo 'Hello World'"
    }
  }
}
```

### Command with Environment Variables

```
resource {
  source "/path/to/script"
  destination "/path/to/output"
  actions {
    execute {
      command "echo $CUSTOM_VAR"
      environment {
        CUSTOM_VAR "test_value"
      }
    }
  }
}
```

### PowerShell on Windows

```
resource {
  source "/path/to/script"
  destination "/path/to/output"
  actions {
    execute {
      command "Get-ChildItem C:\\Windows"
      shell "powershell"
      environment {
        COMPUTER_NAME "$env:COMPUTERNAME"
      }
    }
  }
}
```

## Advanced Features

### Shell Configuration

#### Change Shell Type

```
resource {
  source "/path/to/script"
  destination "/path/to/output"
  actions {
    execute {
      command "echo 'Hello'"
      shell "bash"  # Use bash instead of default sh
    }
  }
}
```

#### Platform-Dependent Shells

The block automatically detects platform and uses the optimal shell:

- On Windows, PowerShell is the default
- On Unix-like systems, `sh` is the default
- Shell can be overridden to match target capabilities if needed

### Environment Management

#### Custom Environment Variables

```
resource {
  source "/path/to/script"
  destination "/path/to/output"
  actions {
    execute {
      command "env | grep CUSTOM"
      environment {
        CUSTOM_VAR "custom_value"
        API_KEY "secret_key"
        DEBUG "true"
      }
    }
  }
}
```

#### Environment Inheritance Control

```
resource {
  source "/path/to/script"
  destination "/path/to/output"
  actions {
    execute {
      command "env"
      inherit_environment false
      environment {
        CUSTOM_VAR "isolated_value"
      }
    }
  }
}
```

### Cross-Platform Path Handling

The execution strategy ensures proper path handling across platforms:

- Windows paths use backslashes and PowerShell quoting
- Unix paths use forward slashes and standard shell quoting
- Path normalization occurs automatically

## Configuration Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `command` | `string` | **required** | Command to execute |
| `shell` | `string` | platform-dependent | Shell type: `sh`, `bash`, `powershell` |
| `environment` | `map` | `{}` | Environment variables to set |
| `working_directory` | `string` | current directory | Working directory for command execution |
| `timeout` | `int` | `300` | Timeout in seconds |
| `input` | `string` | `null` | Input data to send to command |
| `inherit_environment` | `boolean` | `true` | Whether to inherit system environment |
| `max_output_size` | `int` | `1048576` | Maximum output size in bytes (1MB) |
| `on_success` | `boolean` | `false` | Only execute if previous action succeeded |

## State Tracking

The execute module tracks detailed state information after each run:

| Property | Type | Description |
|----------|------|-------------|
| `command` | `string` | Command that was executed |
| `exitCode` | `int` | Exit code of the command |
| `stdout` | `string` | Standard output from command |
| `stderr` | `string` | Standard error from command |
| `executionDuration` | `Duration` | Time taken to execute command |
| `processId` | `int` | Process ID of the executed command |
| `wasKilled` | `boolean` | Whether process was killed due to timeout |
| `environment` | `map` | Environment variables used |
| `workingDirectory` | `string` | Working directory used |
| `timeout` | `int` | Timeout setting in seconds |
| `input` | `string` | Input data sent to command |
| `inheritEnvironment` | `boolean` | Whether system environment was inherited |
| `maxOutputSize` | `int` | Maximum output size limit |

## Examples

### Build Script Execution

```
resource {
  source "/project"
  destination "/build"
  actions {
    execute {
      command "npm run build"
      environment {
        NODE_ENV "production"
        BUILD_TARGET "web"
      }
      working_directory "/project"
      timeout 300
    }
  }
}
```

### Database Migration

```
resource {
  source "/migrations"
  destination "/database"
  actions {
    execute {
      command "migrate up"
      environment {
        DATABASE_URL "postgresql://user:pass@localhost/db"
        MIGRATION_PATH "/migrations"
      }
      timeout 60
    }
  }
}
```

### System Service Management

```
resource {
  source "/services"
  destination "/system"
  actions {
    execute {
      command "systemctl restart nginx"
      timeout 30
    }
  }
}
```

### File Processing with Input

```
resource {
  source "/data/input.txt"
  destination "/data/output.txt"
  actions {
    execute {
      command "process_data.py"
      input "{\"format\": \"json\", \"output\": \"csv\"}"
      environment {
        PYTHONPATH "/scripts"
      }
      timeout 120
    }
  }
}
```

### Backup Script with Environment

```
resource {
  source "/backup"
  destination "/archive"
  actions {
    execute {
      command "backup.sh"
      environment {
        BACKUP_SOURCE "/data"
        BACKUP_DEST "/backup"
        COMPRESSION "gzip"
      }
      working_directory "/scripts"
      timeout 1800
      max_output_size 5120
    }
  }
}
```

### Conditional Cleanup

```
resource {
  source "/temp"
  destination "/clean"
  actions {
    execute {
      command "cleanup_temp_files.sh"
      on_success true
      timeout 60
    }
  }
}
```

## Event System

The execute module emits comprehensive events:

- **StartedEvent**: Execution begins with command and metadata
- **ProgressEvent**: Progress updates for long-running commands
- **CompletedEvent**: Successful execution with exit code and output
- **FailedEvent**: Failed execution with error code and stderr
- **StatusUpdateEvent**: State changes and platform-specific information

All events are automatically redacted for sensitive content.
