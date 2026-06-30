# Raw Action Block

The `raw` action block executes an arbitrary system command directly.

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `command` | string | — | The shell command to execute |

## How It Works

Configr runs the command through the system shell and captures its output. Unlike the `script` block, `raw` takes an inline command string rather than a path to a script file.

## Usage

```bash
configr apply config
```

This will run `uptime` and display the system's uptime information.
