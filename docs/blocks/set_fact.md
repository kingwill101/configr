# Set Fact Block

Sets key/value pairs as context variables for use by subsequent blocks.

## Usage

### Assignment Syntax
```
set_fact {
  app_name = "myapp"
  app_port = "8080"
  app_env = "production"
}
```

### Using the fact Command
```
set_fact {
  fact("version", "1.2.3")
  fact("region", "us-east-1")
}
```

### Dynamic Values from Variables
```
set_fact {
  host_string = "{{ inventory_hostname }}-{{ app_env }}"
}
```

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| Assignment `key = "value"` | `string` | — | Sets a context variable via standard assignment syntax |
| `fact(key, value)` | `command` | — | Sets a context variable using the scoped `fact` command |

All values are stored as strings in the context and may reference other variables using `{{ }}` interpolation.

## Platform Support

| Platform | Implementation |
|----------|---------------|
| Linux | Full |
| macOS | Full |
| FreeBSD | Full |

Cross-platform, pure context operation — no external commands or filesystem access.

## Rollback

No rollback necessary. `set_fact` only modifies in-memory context variables and does not affect system state.
