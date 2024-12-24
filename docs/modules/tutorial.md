# Getting Started with configr Modules

This tutorial will walk you through common module usage patterns.

## Common Usage Patterns

### Basic File Copy

The simplest operation is copying a file:

```
resource {
  source "myfile.txt"
  destination "~/config/myfile.txt"

  actions {
    copy {}
  }
}
```

### Directory Copy

Copy a directory recursively with proper permissions:

```
resource {
  type "directory"
  source "configs/"
  destination "~/.config"

  actions {
    copy {
      recursive true
    }
    permissions {
      mode "644"
      owner "user"
      group "users"
    }
  }
}
```

### Safe File Updates

Make backup before modifying files:

```
resource {
  source "important.conf"
  destination "~/etc/important.conf"

  actions {
    backup {
      backup_path "~/backups/important.conf.bak"
    }
    copy {}
    permissions {
      mode "644"
    }
  }
}
```

### Template Generation

Use templates with variables:

```
resource {
  source "templates/config.template"
  destination "~/app/config.yml"

  template {
    template "config.template"
    vars {
      app_name "MyApp"
      port "8080"
      log_level "info"
    }
  }

  actions {
    copy {}
  }
}
```

### Archive Management

Compress/decompress files:

```
resource {
  type "directory"
  source "logs/"
  destination "logs.tar.gz"

  actions {
    compress {
      format "tar.gz"
      recursive true
    }
  }
}

resource {
  source "logs.tar.gz"
  destination "extracted/"

  actions {
    decompress {
      format "tar.gz"
    }
  }
}
```

### Download and Validate

Download files and validate them:

```
resource {
  source "https://example.com/app.zip"
  destination "downloads/app.zip"

  actions {
    download {
      overwrite true
    }
    validate {
      format "zip"
      checksum "abc123..." # SHA-256 hash
    }
  }
}
```

### Symbolic Links

Create symbolic links for config files:

```
resource {
  source "~/dotfiles/bashrc"

  actions {
    symlink {
      link_path "~/.bashrc"
    }
  }
}
```

### Command Execution

Run commands after file operations:

```
resource {
  source "nginx.conf"
  destination "/etc/nginx/nginx.conf"

  actions {
    copy {}
    validate {
      format "nginx"
    }
    execute {
      command "nginx -t && systemctl reload nginx"
      on_success true
    }
  }
}
```

Each module supports rollback capabilities in case of failures. See individual module docs for complete configuration options.## Common Usage Patterns

### Basic File Copy

The simplest operation is copying a file:

```
resource {
  source "myfile.txt" 
  destination "~/config/myfile.txt"
  
  actions {
    copy {}
  }
}
```

### Directory Copy

Copy a directory recursively with proper permissions:

```
resource {
  type "directory"
  source "configs/"  
  destination "~/.config"
  
  actions {
    copy {
      recursive true
    }
    permissions {
      mode "644"
      owner "user"
      group "users"
    }
  }
}
```

### Safe File Updates

Make backup before modifying files:

```
resource {
  source "important.conf"
  destination "~/etc/important.conf" 
  
  actions {
    backup {
      backup_path "~/backups/important.conf.bak"
    }
    copy {}
    permissions {
      mode "644"
    }
  }
}
```

### Template Generation 

Use templates with variables:

```
resource {
  source "templates/config.template"
  destination "~/app/config.yml"
  
  template {
    template "config.template"
    vars {
      app_name "MyApp"
      port "8080"
      log_level "info"
    }
  }
  
  actions {
    copy {}
  }
}
```

### Archive Management

Compress/decompress files:

```
resource {
  type "directory"  
  source "logs/"
  destination "logs.tar.gz"
  
  actions {
    compress {
      format "tar.gz"
      recursive true
    }
  }
}

resource {
  source "logs.tar.gz"
  destination "extracted/"
  
  actions {
    decompress {
      format "tar.gz"
    }
  }
}
```

### Download and Validate

Download files and validate them:

```
resource {
  source "https://example.com/app.zip"
  destination "downloads/app.zip"
  
  actions {
    download {
      overwrite true
    }
    validate {
      format "zip"
      checksum "abc123..." # SHA-256 hash
    }
  }
}
```

### Symbolic Links

Create symbolic links for config files:

```
resource {
  source "~/dotfiles/bashrc"
  
  actions {
    symlink {
      link_path "~/.bashrc" 
    }
  }
}
```

### Command Execution

Run commands after file operations:

```
resource {
  source "nginx.conf"
  destination "/etc/nginx/nginx.conf"
  
  actions {
    copy {}
    validate {
      format "nginx"
    }
    execute {
      command "nginx -t && systemctl reload nginx"
      on_success true
    }
  }
}
```

Each module supports rollback capabilities in case of failures. See individual module docs for complete configuration options.

## Creating Backups

Before modifying files, you can create backups:

```
resource {
  source "important.conf"
  actions {
    backup {
      backup_path "~/backups/important.conf.bak"
    }
    copy {
      destination "~/config/important.conf"
    }
  }
}
```

## File Templates

Use templates to generate files with variables:

```
resource {
  source "templates/config.template"
  destination "~/app/config.yml"

  template {
    vars {
      app_name "MyApp"
      port 8080
    }
  }

  actions {
    copy {}
  }
}
```

## Setting Permissions

Control file access:

```
resource {
  source "script.sh"
  destination "~/bin/script.sh"

  actions {
    copy {}
    permissions {
      mode "755"
      owner "user"
      group "users"
    }
  }
}
```

## Symlinks

Create symbolic links:

```
resource {
  source "~/dotfiles/bashrc"
  actions {
    symlink {
      link_path "~/.bashrc"
    }
  }
}
```

## Directory Operations

Handle entire directories:

```
resource {
  type "directory"
  source "configs/"
  destination "~/.config"

  actions {
    copy {
      recursive true
    }
    permissions {
      recursive true
      mode "644"
    }
  }
}
```

## Validation

Verify file contents:

```
resource {
  source "config.json"
  actions {
    validate {
      format "json"
    }
    copy {
      destination "~/app/config.json"
    }
  }
}
```

See individual module docs for complete configuration options.
