# Download Block

The `download` block downloads files from remote URLs with progress
tracking, resume capability, authentication, and integrity verification.

## Features

- Resume interrupted downloads
- SHA-256, MD5, SHA-1 checksum validation
- Authentication (Bearer token, Basic auth, API key)
- Progress tracking with timing
- Target-side downloads over SSH, with optional controller relay
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
| `destination` | String | — | Target file path to save to |
| `checksum` | String | — | Expected checksum |
| `checksum_algorithm` | String | `sha256` | Algorithm: `sha256`, `md5`, or `sha1` |
| `transfer_mode` | String | `auto` | `auto`, `remote`, or `controller` |
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
  checksum = "abc123..."
  checksum_algorithm = "sha256"
}

# Resume-capable download
download {
  source = "https://example.com/large-file.iso"
  destination = "downloads/large-file.iso"
  resume = true
}

# Force the remote host to download directly
download {
  source = "https://example.com/large-file.iso"
  destination = "/var/cache/configr/large-file.iso"
  transfer_mode = "remote"
}

# Download on the controller, then copy to the target over SSH/SFTP
download {
  source = "https://example.com/tool.tar.gz"
  destination = "/tmp/tool.tar.gz"
  transfer_mode = "controller"
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

## Remote Targets

When Configr is connected to a host over SSH, `download` writes to the remote
file system.

`transfer_mode = "auto"` downloads directly on the remote host when Configr can
find `curl` plus checksum tooling (`sha256sum`, `sha1sum`, `md5sum`, or
`openssl`). If those tools are unavailable, Configr downloads on the controller
and copies the file to the target over SFTP.

Use `transfer_mode = "remote"` when the target must make the network request
itself, for example to avoid routing large files through the controller or to
use network access that only exists from the target. Use
`transfer_mode = "controller"` when the controller should download the file and
then copy it to the target.
