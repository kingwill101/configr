# Validate Module

Validates file contents and formats before performing operations.

## Usage

```
resource {
  source "config.json"
  destination "/etc/app/config.json"

  actions {
    validate {
      format "json"
      checksum "abc123..." # SHA-256
    }
    copy {}
  }
}
```

## Properties

- `format` (optional) - File format to validate. Supported formats:
  - `json`
  - `yaml`
- `checksum` (optional) - Expected SHA-256 checksum to validate file integrity

## Example

```
# Validate JSON config files
resource {
  source "configs/*.json"
  destination "/etc/app/configs/"

  actions {
    validate {
      format "json"
    }
    copy {
      recursive true
    }
  }
}

# Validate file integrity with checksums
resource {
  source "binary.exe"
  destination "/usr/local/bin/app"

  actions {
    validate {
      checksum "64e604787cbf194841e7b68d7cd28786f6c9a0a3ab9f8b0a0e87cb8387ab0002"
    }
    copy {}
    permissions {
      mode "755"
    }
  }
}
```
