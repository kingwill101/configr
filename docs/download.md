# Download Block

The `download` block downloads files from remote URLs with progress
tracking and integrity verification.

## Features

- Resume interrupted downloads
- SHA-256 checksum validation
- Progress tracking with timing
- Rollback via file deletion

## Basic Usage

```i3
download {
  source = "https://example.com/file.zip"
  destination = "/path/to/downloaded/file.zip"
}
```

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `source` | String | — | URL to download from |
| `destination` | String | — | Local file path to save to |
| `sha256` | String | — | Expected SHA-256 checksum |
| `overwrite` | Bool | `false` | Overwrite existing file |

## Examples

```i3
# Download with checksum verification
download {
  source = "https://get.docker.com/"
  destination = "docker.sh"
  sha256 = "abc123..."
}

# Download with overwrite
download {
  source = "https://example.com/file.zip"
  destination = "~/downloads/file.zip"
  overwrite = true
}
```

## Rollback

Rollback deletes the downloaded file.
