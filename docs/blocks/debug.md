# Debug Block

Prints messages and variable values to stdout through the logging system. Useful for debugging i3config templates and inspecting variable state during execution.

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `msg` | `string` | `""` | Message to print |
| `var` | `string` | `""` | Variable name to inspect and print its value |

## Examples

### Print a Message

```
debug {
  msg = "Processing resource: {{ resource_name }}"
}
```

### Inspect a Variable

```
debug {
  var = "os_family"
}
```

### Both Message and Variable

```
debug {
  msg = "Current target details"
  var = "inventory_hostname"
}
```

## Platform Support

| Platform | Implementation |
|----------|---------------|
| Linux | Full |
| macOS | Full |
| FreeBSD | Full |

## Rollback

No rollback needed. The debug block does not modify any system state.
