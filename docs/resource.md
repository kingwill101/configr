Here’s a detailed Markdown documentation for all the actions, their purposes, and their required/optional parameters.

---

# Configuration Manager Actions Documentation

This document describes the available actions for managing files, directories, and other resources in a configuration manager. Each action serves a specific purpose and can be used in different contexts such as deployment, maintenance, backup, and more.

## Actions Overview

| Action    | Description                                                            |
|-----------|------------------------------------------------------------------------|
| `copy`    | Copies a file or directory to a specified destination.                 |
| `symlink` | Creates a symbolic link pointing to the source file or directory.       |
| `move`    | Moves a file or directory to a new location.                           |
| `delete`  | Deletes a file or directory.                                           |
| `rename`  | Renames a file or directory.                                           |
| `download`| Downloads a file from a remote server.                                 |
| `compress`| Compresses files or directories into an archive.                       |
| `decompress`| Decompresses an archive into the specified destination.              |
| `validate`| Validates the integrity or structure of a file.                        |
| `execute` | Runs a command or script after performing actions on a resource.       |
| `touch`   | Updates the modification time of a file or creates an empty file.      |
| `permissions` | Sets ownership and permissions for a file or directory.            |

---

## 1. `copy`

### Purpose:
Copies a file or directory from the source to the destination.

### Parameters:
- **Required**:
    - `source`: The path to the file or directory to be copied.
    - `destination`: The path where the file or directory will be copied to.
- **Optional**:
    - `backup`:
        - `backup_path`: Path where the original file or directory will be backed up if it exists at the destination.
    - `recursive`: Set to `true` if copying a directory and want to copy its contents recursively.

### Example:
```yaml
resource {
  type "directory"
  source "/etc/myapp/config"
  destination "/backup/myapp/config"

  actions {
    copy {
      recursive true
      backup {
        backup_path "/backup/myapp/config.bak"
      }
    }
  }
}
```

---

## 2. `symlink`

### Purpose:
Creates a symbolic link pointing to the source file or directory.

### Parameters:
- **Required**:
    - `source`: The path to the original file or directory.
    - `link_path`: The path where the symlink will be created.
- **Optional**:
    - None

### Example:
```yaml
resource {
  type "file"
  source "/etc/myapp/config.json"
  destination "/var/www/html/config.json"

  actions {
    symlink {
      link_path "/var/www/html/config.json"
    }
  }
}
```

---

## 3. `move`

### Purpose:
Moves a file or directory from the source to the destination.

### Parameters:
- **Required**:
    - `source`: The path to the file or directory to move.
    - `destination`: The destination path where the file or directory will be moved.
- **Optional**:
    - `overwrite`: Set to `true` to overwrite the destination if a file or directory already exists there (default is `false`).

### Example:
```yaml
resource {
  type "file"
  source "/tmp/temp_config.conf"
  destination "/etc/myapp/config.conf"

  actions {
    move {
      overwrite true
    }
  }
}
```

---

## 4. `delete`

### Purpose:
Deletes a file or directory from the destination.

### Parameters:
- **Required**:
    - `destination`: The path of the file or directory to be deleted.
- **Optional**:
    - `backup`:
        - `backup_path`: Path where the file or directory will be backed up before deletion (if applicable).

### Example:
```yaml
resource {
  type "file"
  destination "/etc/myapp/old_config.conf"

  actions {
    delete {
      backup {
        backup_path "/etc/myapp/old_config.conf.bak"
      }
    }
  }
}
```

---

## 5. `rename`

### Purpose:
Renames a file or directory.

### Parameters:
- **Required**:
    - `source`: The current name of the file or directory.
    - `destination`: The new name of the file or directory.
- **Optional**:
    - `overwrite`: Set to `true` to overwrite the destination if a file or directory with the new name already exists (default is `false`).

### Example:
```yaml
resource {
  type "file"
  source "/etc/myapp/temp_config.conf"
  destination "/etc/myapp/prod_config.conf"

  actions {
    rename {
      overwrite false
    }
  }
}
```

---

## 6. `download`

### Purpose:
Downloads a file from a remote URL and stores it in the specified destination.

### Parameters:
- **Required**:
    - `source`: The remote URL of the file to download.
    - `destination`: The local path where the downloaded file will be stored.
- **Optional**:
    - `overwrite`: Set to `true` to overwrite the destination if the file already exists (default is `false`).

### Example:
```yaml
resource {
  type "file"
  source "https://example.com/config.json"
  destination "/etc/myapp/config.json"

  actions {
    download {
      overwrite true
    }
  }
}
```

---

## 7. `compress`

### Purpose:
Compresses files or directories into an archive.

### Parameters:
- **Required**:
    - `source`: The path to the file or directory to compress.
    - `destination`: The path where the compressed archive will be created.
- **Optional**:
    - `format`: The archive format (e.g., `zip`, `tar.gz`).
    - `recursive`: Set to `true` to compress the entire directory structure recursively (if applicable).

### Example:
```yaml
resource {
  type "directory"
  source "/var/log/myapp"
  destination "/backups/myapp_logs.tar.gz"

  actions {
    compress {
      format "tar.gz"
      recursive true
    }
  }
}
```

---

## 8. `decompress`

### Purpose:
Decompresses an archive into the specified destination directory.

### Parameters:
- **Required**:
    - `source`: The path to the compressed archive (e.g., `zip`, `tar.gz`).
    - `destination`: The path where the files will be extracted.
- **Optional**:
    - `format`: The archive format (e.g., `zip`, `tar.gz`).

### Example:
```yaml
resource {
  type "file"
  source "/backups/myapp_logs.tar.gz"
  destination "/var/log/myapp"

  actions {
    decompress {
      format "tar.gz"
    }
  }
}
```

---

## 9. `validate`

### Purpose:
Validates the integrity or structure of a file.

### Parameters:
- **Required**:
    - `source`: The path to the file to validate.
- **Optional**:
    - `checksum`: The expected checksum (e.g., `sha256`) for file integrity validation.
    - `format`: The expected file format (e.g., `json`, `yaml`) for structure validation.

### Example:
```yaml
resource {
  type "file"
  source "/etc/myapp/config.json"

  actions {
    validate {
      checksum "sha256:abc123..."
      format "json"
    }
  }
}
```

---

## 10. `execute`

### Purpose:
Executes a command or script after performing actions on a resource.

### Parameters:
- **Required**:
    - `command`: The command to execute.
- **Optional**:
    - `on_success`: Set to `true` to run the command only if the previous action(s) succeeded (default is `false`).

### Example:
```yaml
resource {
  type "file"
  source "/etc/myapp/new_config.conf"

  actions {
    copy {
      backup {
        backup_path "/etc/myapp/config.conf.bak"
      }
    }
    execute {
      command "systemctl restart myapp"
      on_success true
    }
  }
}
```

---

## 11. `touch`

### Purpose:
Updates the modification time of a file or creates an empty file if it doesn't exist.

### Parameters:
- **Required**:
    - `destination`: The path of the file to be touched.
- **Optional**:
    - `create_if_missing`: Set to `true` to create the file if it doesn't exist (default is `false`).

### Example:
```yaml
resource {
  type "file"
  destination "/var/run/myapp/trigger.txt"

  actions {
    touch {
      create_if_missing true
    }
  }
}
```

---

## 12. `permissions`

### Purpose:
Sets the ownership and permissions for a file or directory.

### Parameters:
- **Required**:
    - `destination`: The path to the file or directory.
- **Optional**:
    - `owner`: The user who should own the file or directory.
    - `group`: The group that should own the file or directory.
    - `mode`: The permissions for the file or directory (e.g., `0755`).
    - `recursive`: Set to `true` to apply permissions recursively (if applicable).

### Example:
```yaml
resource {
  type "directory"
  destination "/etc/myapp"

  actions {
    permissions {
      owner "root"
      group "root"
      mode "0755"
      recursive true
    }
  }
}
```

