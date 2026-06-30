# Unarchive Action Block

The `unarchive` action block extracts archive files (tar, zip, tar.gz, etc.) to a destination directory.

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `src` | string | — | Path to the archive file |
| `dest` | string | — | Directory to extract the archive into |
| `remote_src` | bool | `false` | Whether the archive is on a remote target |

## How It Works

Configr extracts the archive at `src` into the `dest` directory. When `remote_src` is `true`, the archive is first fetched from the target before extraction. Supported formats include `.tar`, `.tar.gz`, `.tgz`, `.zip`, and `.tar.bz2`.

## Usage

```bash
configr apply config
```

This will extract `/tmp/app.tar.gz` into `/opt/app`. Since `remote_src` is `true`, the archive is pulled from the remote target first.
