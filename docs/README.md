# configr Modules

Modules are the core building blocks of configr that handle specific file operations. Each module implements a specific action that can be performed on files and directories.

## Core Modules

- [Backup](backup.md) - Creates backup copies of files/directories before modifications
- [Copy](copy.md) - Copies files/directories to new locations
- [Compress](compress.md) - Compresses files/directories into archives
- [Decompress](decompress.md) - Extracts files from archives
- [Delete](delete.md) - Safely deletes files with optional backup
- [Download](download.md) - Downloads files from remote URLs
- [Execute](execute.md) - Executes shell commands on files
- [Move](move.md) - Moves/renames files and directories
- [Permissions](permissions.md) - Sets file permissions and ownership
- [Rename](rename.md) - Renames files and directories with rollback support
- [Symlink](symlink.md) - Creates/manages symbolic links
- [Template](template.md) - Renders template files with variables
- [Touch](touch.md) - Updates file timestamps or creates empty files
- [Validate](validate.md) - Validates file contents and formats## Core Modules

## Using Modules

Each module can be used in your config file by adding it as an action. For example:

```
resource {
  source "myfile.txt"
  destination "~/config/myfile.txt"

  actions {
    copy {}
    permissions {
      mode "644"
    }
  }
}
```

See the individual module documentation for specific configuration options.
