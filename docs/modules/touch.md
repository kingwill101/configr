# Touch Module

Updates file timestamps or creates empty files.

## Usage

```
resource {
  destination "file.txt"

  actions {
    touch {
      create_if_missing true
    }
  }
}
```

## Properties

- `create_if_missing` (optional) - Create file if it doesn't exist (default: false)

## Example

```
# Create empty file
resource {
  destination ".gitkeep"

  actions {
    touch {
      create_if_missing true
    }
  }
}

# Update timestamp on log file
resource {
  destination "app.log"

  actions {
    touch {}
  }
}

# Create multiple placeholder files
resource {
  destination "logs/.gitkeep"

  actions {
    touch {
      create_if_missing true
    }
    permissions {
      mode "644"
    }
  }
}
```
