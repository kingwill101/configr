# Backup Module

Creates backup copies of files and directories before modifications.

## Usage

```
resource {
  source "myfile.txt"
  actions {
    backup {
      backup_path "~/backups/myfile.txt.bak"
      recursive true  # For directories
    }
  }
}
```

## Properties

- `backup_path` (required) - Path where backup will be stored
- `recursive` (optional) - Backup directories recursively if true

## Example

```
resource {
  source "~/.config/app"
  type "directory"
  actions {
    backup {
      backup_path "~/backups/app-config" 
      recursive true
    }
    # Other actions that modify the files...
  }
}
```