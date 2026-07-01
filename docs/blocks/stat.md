# Stat Block

Retrieves file and directory metadata with optional checksum computation.

## Usage

### Basic File Stats
```
stat {
  path = "/etc/hostname"
}
```

### Stat with Checksum
```
stat {
  path = "/etc/nginx/nginx.conf"
  checksum_algorithm = "sha256"
}
```

### Stat Without Following Symlinks
```
stat {
  path = "/etc/localtime"
  follow = false
}
```

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `path` | `string` | `""` | Path to the file or directory to stat |
| `follow` | `boolean` | `true` | Whether to follow symlinks |
| `checksum_algorithm` | `string` | `"sha256"` | Checksum algorithm: `md5`, `sha1`, `sha256`, `sha512` |

## Platform Support

| Platform | Implementation |
|----------|---------------|
| Linux | Full (includes uid/gid via `stat` command) |
| macOS | Full (uid/gid unavailable) |
| FreeBSD | Full (uid/gid unavailable) |
| Windows | Partial (no uid/gid, limited metadata) |

## Context Variables Set

| Variable | Description |
|----------|-------------|
| `stat_exists` | Whether the path exists (`true`/`false`) |
| `stat_isdir` | Whether the path is a directory |
| `stat_isreg` | Whether the path is a regular file |
| `stat_islnk` | Whether the path is a symbolic link |
| `stat_type` | Type string: `file`, `directory`, `link`, `other` |
| `stat_mode` | Unix file mode in octal (e.g., `644`) - Linux/macOS/FreeBSD only |
| `stat_size` | File size in bytes |
| `stat_mtime` | Last modification time (ISO 8601 UTC) |
| `stat_atime` | Last access time (ISO 8601 UTC) |
| `stat_ctime` | Last change time (ISO 8601 UTC) |
| `stat_uid` | Owner user ID (Linux only - unavailable on Windows) |
| `stat_gid` | Owner group ID (Linux only - unavailable on Windows) |
| `stat_checksum` | File checksum hex digest (regular files only) |

## Rollback

No rollback necessary. `stat` is a read-only operation that does not modify system state.
