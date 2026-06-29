# Pause Block

Pauses execution for a specified duration using `Future.delayed`. Useful for waiting between actions.

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `seconds` | `int` | `0` | Number of seconds to pause |
| `minutes` | `int` | `0` | Number of minutes to pause |

The total pause duration is `seconds + minutes * 60`. At least one property must be set to a positive value.

## Examples

### Pause for 10 Seconds

```
pause {
  seconds = 10
}
```

### Pause for 5 Minutes

```
pause {
  minutes = 5
}
```

### Combined Duration

```
pause {
  minutes = 1
  seconds = 30
}
```

## Platform Support

| Platform | Implementation |
|----------|---------------|
| Linux    | Full |
| macOS    | Full |
| FreeBSD  | Full |

## Interactive Prompt

The `prompt` property exists for compatibility but is **not supported** in non-interactive mode. Setting `prompt` without `seconds` or `minutes` will throw an error:

```
pause {
  prompt = "Press enter to continue..."
}
```

## Rollback

No rollback is performed — the pause has already completed.
