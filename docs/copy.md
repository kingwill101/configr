# Copy Module 

Copies files and directories to new locations.

## Usage

```
resource {
  source "myfile.txt"
  destination "~/config/myfile.txt"
  actions {
    copy {
      recursive true  # For directories
    }
  }
}
```

## Properties

- `recursive` (optional) - Copy directories recursively if true

## Example

```
# Copy entire directory
resource {
  type "directory" 
  source "configs/"
  destination "~/.config"
  actions {
    copy {
      recursive true
    }
  }
}

# Copy single file
resource {
  source "bashrc"
  destination "~/.bashrc"
  actions {
    copy {}
  }
}
```