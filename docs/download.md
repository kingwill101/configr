# Download Module

Downloads files from remote URLs.

## Usage

```
resource {
  source "https://example.com/file.zip"
  destination "downloads/file.zip"

  actions {
    download {
      overwrite true
      checksum "abc123..." # Optional SHA-256 validation
    }
  }
}
```

## Properties

- `overwrite` (optional) - Whether to overwrite existing files (default: false)
- `checksum` (optional) - Expected SHA-256 checksum to validate downloaded file

## Example

```
# Download and verify an application
resource {
  source "https://example.com/app-v1.0.0.tar.gz"
  destination "/tmp/app.tar.gz"

  actions {
    download {
      overwrite true
      checksum "64e604787cbf194841e7b68d7cd28786f6c9a0a3ab9f8b0a0e87cb8387ab0002"
    }
    decompress {
      format "tar.gz"
    }
    permissions {
      mode "755"
      recursive true
    }
  }
}

# Download configuration files
resource {
  source "https://config-server/app-config.json"
  destination "/etc/app/config.json"

  actions {
    backup {
      backup_path "/etc/app/config.json.bak"
    }
    download {
      overwrite true
    }
    validate {
      format "json"
    }
  }
}
```
