# Echo Block

Prints messages to the console through the event system with configurable severity level and optional color formatting.

## Usage

### Basic Message
```
echo {
  message = "Installation complete!"
}
```

### With Severity Level
```
echo {
  message = "Warning: configuration drift detected"
  level = "warning"
}

echo {
  message = "Error: critical service failure"
  level = "error"
}

echo {
  message = "Debug: processing file /etc/config"
  level = "debug"
}
```

### Without Color
```
echo {
  message = "Plain text output"
  color = false
}
```

### Verbose Mode
```
echo {
  message = "Detailed log message"
  verbose = true
}
```

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `message` | `string` | `""` | The message to print |
| `level` | `string` | `"info"` | Severity level: `info`, `warning`, `error`, or `debug` |
| `color` | `boolean` | `true` | Enable/disable color output |
| `verbose` | `boolean` | `false` | Only show message in verbose mode |

## Behavior

- **No operation performed**: Echo does not modify any files or system state
- **No rollback needed**: The `level`, `color`, and `verbose` properties are not stored in the lockfile
- **Dry run**: Appears in dry-run summary as `echo[level]: message` or `echo: id=<block_id>`