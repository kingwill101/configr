# Execute Module

Executes shell commands after performing file operations.

## Usage

```
resource {
  source "config.conf"
  destination "/etc/app/config.conf"

  actions {
    copy {}
    execute {
      command "systemctl reload app"
      on_success true
    }
  }
}
```

## Properties

- `command` (required) - The shell command to execute
- `on_success` (optional) - Only run command if previous actions succeeded (default: false)

## Example

```
# Restart nginx after config change
resource {
  source "nginx.conf"
  destination "/etc/nginx/nginx.conf"

  actions {
    copy {}
    validate {
      format "nginx"
    }
    execute {
      command "nginx -t && systemctl reload nginx"
      on_success true
    }
  }
}

# Run database migrations after update
resource {
  source "migrations/"
  destination "/app/migrations"
  type "directory"

  actions {
    copy {
      recursive true
    }
    execute {
      command "cd /app && ./run-migrations.sh"
      on_success true
    }
  }
}
```
