# Unarchive Block

Extracts compressed archives to a destination directory.

## Usage

### Extract a tar.gz Archive
```
unarchive {
  src = "/tmp/app.tar.gz"
  dest = "/opt/myapp"
}
```

### Extract with Format Override
```
unarchive {
  src = "/tmp/data.zip"
  dest = "/var/lib/data"
  format = "zip"
}
```

### Conditional Extraction
```
unarchive {
  src = "/tmp/config.tgz"
  dest = "/etc/myapp"
  creates = "/etc/myapp/config.yaml"
  list_files = true
}
```

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `src` | `string` | `""` | Path to the archive file |
| `dest` | `string` | `""` | Destination directory for extraction |
| `remote_src` | `boolean` | `false` | Whether `src` is already on the target (vs copied from source) |
| `format` | `string` | `"auto"` | Archive format: `auto`, `gzip`, `bzip2`, `xz`, `tar`, `zip`. Auto-detects from file extension |
| `list_files` | `boolean` | `false` | If true, sets `unarchive_files` context variable with archive listing |
| `creates` | `string` | `""` | Path to check; if it exists, extraction is skipped (idempotency) |
| `extra_opts` | `string` | `""` | Extra options passed to the extraction command (space-separated) |

## Auto-Detected Formats

| Extension | Format |
|-----------|--------|
| `.tar.gz`, `.tgz` | `gzip` |
| `.tar.bz2`, `.tbz`, `.tbz2` | `bzip2` |
| `.tar.xz`, `.txz` | `xz` |
| `.tar` | `tar` |
| `.zip` | `zip` |
| `.gz` | `gunzip` |
| `.bz2` | `bunzip2` |

## Context Variables Set

| Variable | Description |
|----------|-------------|
| `unarchive_files` | Archive file listing (when `list_files` is true) |

## Platform Support

| Platform | Implementation | Commands Used |
|----------|---------------|---------------|
| Linux | Full | `tar`, `unzip`, `gunzip`, `bunzip2` |
| macOS | Full | `tar`, `unzip`, `gunzip`, `bunzip2` |
| FreeBSD | Full | `tar`, `unzip`, `gunzip`, `bunzip2` |

Cross-platform — relies on standard POSIX archive utilities.

## Rollback

No rollback implemented. Extracted files are not tracked for deletion on rollback.
