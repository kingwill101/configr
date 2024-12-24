# Compress Module

Compresses files and directories into archives.

## Usage

```
resource {
  type "directory"
  source "logs/"
  destination "archive.tar.gz"

  actions {
    compress {
      format "tar.gz"    # or "zip"
      recursive true
    }
  }
}
```

## Properties

- `format` (required) - Archive format to create. Supported formats:
  - `tar.gz` - Creates gzipped tar archive
  - `zip` - Creates ZIP archive
- `recursive` (optional) - Include subdirectories when compressing (default: false)

## Example

```
# Archive old logs
resource {
  type "directory"
  source "/var/log/app/old"
  destination "/backup/logs.tar.gz"

  actions {
    compress {
      format "tar.gz"
      recursive true
    }
  }
}

# Package application files
resource {
  type "directory"
  source "dist/"
  destination "app.zip"

  actions {
    # First ensure proper permissions
    permissions {
      mode "644"
      recursive true
    }

    # Then create archive
    compress {
      format "zip"
      recursive true
    }

    # Optionally validate the archive
    validate {
      format "zip"
    }
  }
}

# Archive with backup
resource {
  type "directory"
  source "config/"
  destination "config.tar.gz"

  actions {
    backup {
      backup_path "config.tar.gz.bak"
    }
    compress {
      format "tar.gz"
      recursive true
    }
  }
}
```
