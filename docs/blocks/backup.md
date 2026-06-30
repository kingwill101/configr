# Backup Module

Creates backup copies of files and directories before modifications with support for incremental backups, compression, and encryption.

## Usage

### Basic Backup
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

### Enhanced Backup with Compression
```
resource {
  source "~/.config/app"
  actions {
    backup {
      backup_path "~/backups/app-config.zip"
      compression true
      compression_format "zip"  # or "tar.gz"
      recursive true
    }
  }
}
```

### Incremental Backup
```
resource {
  source "~/.config/app"
  actions {
    backup {
      backup_path "~/backups/app-config"
      incremental true
      recursive true
    }
  }
}
```

### Encrypted Backup
```
resource {
  source "sensitive-data.txt"
  actions {
    backup {
      backup_path "~/backups/sensitive-data.enc"
      encryption true
      encryption_key "my-secret-key"
      encryption_algorithm "aes-256-gcm"
    }
  }
}
```

### Full Featured Backup
```
resource {
  source "~/.config/app"
  actions {
    backup {
      backup_path "~/backups/app-config.zip"
      incremental true
      compression true
      compression_format "zip"
      encryption true
      encryption_key "my-secret-key"
      recursive true
    }
  }
}
```

## Properties

### Basic Properties
- `backup_path` (required) - Path where backup will be stored
- `recursive` (optional) - Backup directories recursively if true

### Enhanced Properties
- `incremental` (optional) - Enable incremental backups (default: false)
- `compression` (optional) - Enable compression (default: false)
- `compression_format` (optional) - Compression format: "zip" or "tar.gz" (default: "zip")
- `encryption` (optional) - Enable encryption (default: false)
- `encryption_key` (optional) - Encryption key (required when encryption is enabled)
- `encryption_algorithm` (optional) - Encryption algorithm (default: "aes-256-gcm")

## Features

### Incremental Backups
- Only backs up files that have changed since the last backup
- Uses SHA-256 hashing to detect file changes
- Creates a manifest file to track file states
- Significantly reduces backup time and storage for unchanged files

### Compression
- Supports ZIP and TAR.GZ formats
- Reduces backup file size
- Can be combined with encryption

### Encryption
- Simple XOR encryption for demonstration (use proper encryption in production)
- Encrypts the entire backup archive
- Requires an encryption key

### Manifest Files
- Created automatically for incremental backups
- Contains file hashes and metadata
- Used to determine which files have changed
- Stored as `.manifest` files alongside backups

## Examples

### Directory Backup with All Features
```
resource {
  source "~/.config/myapp"
  actions {
    backup {
      backup_path "~/backups/myapp-full.zip"
      incremental true
      compression true
      compression_format "zip"
      encryption true
      encryption_key "secure-key-123"
      recursive true
    }
  }
}
```

### Simple File Backup
```
resource {
  source "important.txt"
  actions {
    backup {
      backup_path "~/backups/important.txt.bak"
    }
  }
}
```

### Compressed Directory Backup
```
resource {
  source "project-files"
  actions {
    backup {
      backup_path "~/backups/project-files.tar.gz"
      compression true
      compression_format "tar.gz"
      recursive true
    }
  }
}
```