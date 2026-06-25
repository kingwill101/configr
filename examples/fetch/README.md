# Fetch Action Block

The `fetch` action block copies a file from a remote target (or local path) to the local machine.

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `src` | string | — | Source file path on the target |
| `dest` | string | — | Local destination path or directory |

## How It Works

Configr reads the file at `src` and transfers it to the local `dest` path. This is useful for backing up remote configuration files or collecting logs.

## Usage

```bash
configr apply config
```

This will copy `/var/log/syslog` from the target into the local `./backups/` directory.
