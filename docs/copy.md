# Copy Block

The `copy` block copies files or directories to a new location with
selective copying, progress tracking, and conflict resolution.

## Features

- **Selective Copying**: Include/exclude files using glob patterns
- **Progress Tracking**: Real-time progress monitoring with counters
- **Conflict Resolution**: Multiple strategies for existing files
- **Rollback**: Deletes copied files/directories on rollback

## Basic Usage

```i3
copy {
  source = "/path/to/source/file.txt"
  destination = "/path/to/destination/file.txt"
}
```

```i3
copy {
  source = "/path/to/source/directory"
  destination = "/path/to/destination/directory"
}
```

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `source` | String | — | Source file or directory path |
| `destination` | String | — | Destination path |
| `include` | String | — | Glob pattern for files to include |
| `exclude` | String | — | Glob pattern for files to exclude |
| `overwrite` | Bool | `false` | Overwrite existing files |

## Examples

```i3
# Copy with glob filtering
copy {
  source = "configs/"
  destination = "~/.config"
  include = "*.toml"
  exclude = "*.bak"
}

# Force overwrite
copy {
  source = "dotfiles/bashrc"
  destination = "~/.bashrc"
  overwrite = true
}
```

## Rollback

Rollback deletes the destination file or directory that was created during apply.
