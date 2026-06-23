# File Block

Creates, edits, or removes files with backup support and full rollback capability.

## Usage

### Create a File
```
file {
  destination = "~/.bashrc"
  content = """
export EDITOR=vim
export PATH="$HOME/bin:$PATH"
"""
  create_directories = true
}
```

### Edit Existing File
```
file {
  destination = "~/.bashrc"
  content = "\nexport EDITOR=nvim\n"
  operation = "edit"
  edit_mode = "append"
  backup_original = true
}
```

### Remove a File
```
file {
  destination = "/tmp/old-config.conf"
  operation = "remove"
  backup_original = true
}
```

### Prepend Content
```
file {
  destination = "/etc/hosts"
  content = "127.0.0.1 local-app\n"
  operation = "edit"
  edit_mode = "prepend"
}
```

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `destination` | `string` (required) | - | Path to the file |
| `content` | `string` | `""` | Content to write (for create/edit) |
| `operation` | `string` | `"create"` | Operation type: `create`, `edit`, or `remove` |
| `edit_mode` | `string` | `"replace"` | Edit mode: `replace`, `append`, or `prepend` |
| `create_directories` | `boolean` | `true` | Create parent directories if they don't exist |
| `backup_original` | `boolean` | `false` | Create backup before modification |
| `backup_suffix` | `string` | `".backup"` | Suffix for backup files |

## Operations

### `create`
Creates a new file with the specified content. If the file exists:
- Original content is stored for rollback
- Backup is created if `backup_original` is true

### `edit`
Modifies an existing file's content. Fails if file doesn't exist.

**Edit modes:**
- `replace` — Overwrites entire file
- `append` — Adds content to end of file
- `prepend` — Adds content to beginning of file

### `remove`
Deletes the file. Original content is stored for rollback.

## Rollback

The file block fully supports rollback:
- Restored original content if file was modified
- Restored deleted files
- Removes backup files created during operation