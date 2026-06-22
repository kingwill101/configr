# Download Block

The `download` block downloads files from remote URLs with progress
tracking, resume capability, authentication, and integrity verification.

## Features

- Resume interrupted downloads
- SHA-256, MD5, SHA-1 checksum validation
- Authentication (Bearer token, Basic auth, API key)
- Progress tracking with timing
- Rollback via file deletion or content restoration

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
| `md5` | String | — | Expected MD5 checksum |
| `sha1` | String | — | Expected SHA-1 checksum |
| `checksum_algorithm` | String | `sha256` | Algorithm: `sha256`, `md5`, or `sha1` |
| `overwrite` | Bool | `false` | Overwrite existing file |
| `resume` | Bool | `false` | Resume interrupted download |
| `auth_type` | String | — | Auth type: `bearer`, `basic`, or `api_key` |
| `auth_token` | String | — | Token for bearer/api_key auth |
| `username` | String | — | Username for basic auth |
| `password` | String | — | Password for basic auth |

## Examples

```i3
# Download with checksum verification
download {
  source = "https://get.docker.com/"
  destination = "docker.sh"
  sha256 = "abc123..."
}

# Resume-capable download
download {
  source = "https://example.com/large-file.iso"
  destination = "downloads/large-file.iso"
  resume = true
}

# Authenticated download
download {
  source = "https://api.example.com/release.zip"
  destination = "release.zip"
  auth_type = "bearer"
  auth_token = "tok_xxxxx"
}

# Download with overwrite
download {
  source = "https://example.com/file.zip"
  destination = "~/downloads/file.zip"
  overwrite = true
}
```

## Rollback

Rollback deletes the downloaded file. If the file existed before
download, its original content is restored.
