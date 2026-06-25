# Script Action Block

The `script` action block runs a local script file as part of your configuration.

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `script` | string | — | Path to the script file to execute |
| `args` | string | `""` | Command-line arguments passed to the script |
| `chdir` | string | `""` | Working directory to run the script in |

## How It Works

Configr finds the script file at the given path, changes to the specified working directory (if provided), and executes the script with the given arguments. The script must be executable.

## Usage

```bash
configr apply config
```

This will run `./deploy.sh --verbose` from the `/tmp` directory.
