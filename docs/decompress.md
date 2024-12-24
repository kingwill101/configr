# Decompress Module

Extracts files from compressed archives.

## Usage

```
resource {
  type "file"
  source "archive.tar.gz"
  destination "extracted/"

  actions {
    decompress {
      format "tar.gz" # or "zip"
    }
  }
}
```

## Properties

- `format` (required) - Archive format to decompress. Supported formats:
  - `tar.gz`
  - `zip`

## Example

```
resource {
  source "backups/config.tar.gz"
  destination "~/.config"

  actions {
    # Extract configs
    decompress {
      format "tar.gz"
    }

    # Set proper permissions
    permissions {
      mode "644"
      recursive true
    }
  }
}
```
