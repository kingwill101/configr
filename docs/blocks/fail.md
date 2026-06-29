# Fail Block

Always fails with a custom error message. Useful for conditional validation, guard clauses, and halting execution when prerequisites are not met.

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `msg` | `string` | `"Assertion failed"` | Failure message thrown as `ActionFailedException` |

## Examples

### Basic Failure

```
fail {
  msg = "Required package not installed"
}
```

### Conditional Validation (with when)

```
fail {
  msg = "Only supported on Linux"
}
```

### Guard Clause for Missing Variables

```
fail {
  msg = "Required variable 'deploy_key' is not set"
}
```

## Platform Support

| Platform | Implementation |
|----------|---------------|
| Linux | Full |
| macOS | Full |
| FreeBSD | Full |

## Rollback

No rollback needed. The fail block halts execution before any state changes occur.
