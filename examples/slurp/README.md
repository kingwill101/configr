# Slurp Action Block

The `slurp` action block reads a file and base64-encodes its contents for use in templates or variables.

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `src` | string | — | Path to the file to read and encode |

## How It Works

Configr reads the file at `src` and base64-encodes the content. The encoded result can be used in downstream actions, templates, or stored for later decoding. This is useful for embedding binary files or configuration values in text-safe formats.

## Usage

```bash
configr apply config
```

This will read `/etc/hostname` and output its base64-encoded content.
