# Symlink Module

Creates and manages symbolic links.

## Usage

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

## Properties

- `link_path` (required) - Path where the symbolic link will be created

## Example

```
# Link dotfiles
resource {
  source "~/dotfiles/bashrc"

  actions {
    symlink {
      link_path "~/.bashrc"
    }
  }
}

# Link config directory
resource {
  type "directory"
  source "~/projects/app/config"

  actions {
    symlink {
      link_path "~/.config/app"
    }
  }
}

# Link with backup
resource {
  source "~/dotfiles/vimrc"

  actions {
    backup {
      backup_path "~/.vimrc.bak"
    }
    symlink {
      link_path "~/.vimrc"
    }
  }
}
```
