# Configr Documentation

> For a complete overview, see the [Documentation Index](../index.md).

## Overview

Configr is a configuration management tool for dotfiles and system
configuration. It uses the i3config-format for declarative, block-based
configuration files with full rollback support.

### v2 Pipeline

Configr v2 uses the i3config v2 state machine for parsing and processing.
Action blocks are registered as `BlockHandler` subclasses and executed
automatically during config processing. The `--v2` flag enables the new
pipeline.

### Action Blocks

Each action type has a corresponding block:

- [Backup](../blocks/backup.md) — Create backup copies before modifications
- [Copy](../blocks/copy.md) — Copy files/directories to new locations
- [Compress](../blocks/compress.md) — Compress files/directories into archives
- [Decompress](../blocks/decompress.md) — Extract files from archives
- [Delete](../blocks/delete.md) — Safely delete files and directories
- [Download](../blocks/download.md) — Download files from remote URLs
- [Execute](../blocks/execute.md) — Execute shell commands
- [Move](../blocks/move.md) — Move/rename files and directories
- [Permissions](../blocks/permissions.md) — Set file permissions and ownership
- [Rename](../blocks/rename.md) — Rename files and directories
- [Symlink](../blocks/symlink.md) — Create/manage symbolic links
- [Template](../blocks/template.md) — Render template files with Liquid
- [Touch](../blocks/touch.md) — Update file timestamps
- [Validate](../blocks/validate.md) — Validate file contents and formats

### Example

```i3
copy {
  source = "dotfiles/bashrc"
  destination = "~/.bashrc"
}

permissions {
  source = "dotfiles/bashrc"
  destination = "~/.bashrc"
  mode = "644"
}
```

### CLI Commands

See the [CLI Usage Guide](cli-usage.md) for detailed command reference.

- `configr init --v2` — Initialize a configuration
- `configr apply --v2` — Apply configuration
- `configr rollback --v2` — Rollback changes
- `configr diff --v2` — Show diff
- `configr status --v2` — Show status
- `configr format --v2` — Format config file
- `configr add --v2` — Add a block
- `configr edit --v2` — Edit config file
- `configr watch --v2` — Watch and auto-apply

### Migration

See the [Migration Guide](migration-guide.md) for upgrading from v1 to v2.
