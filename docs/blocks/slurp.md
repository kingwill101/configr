# Slurp Block

Reads a file from disk and base64-encodes its content, storing the result as context variables.

## Usage

### Read a Configuration File
```
slurp {
  src = "/etc/nginx/nginx.conf"
}
```

### Read a Binary File
```
slurp {
  src = "/usr/share/icons/logo.png"
}
```

### Using Slurp Content in a Subsequent Block
```
slurp {
  src = "/etc/ssh/sshd_config"
}

uri {
  url = "https://api.example.com/configs"
  method = "POST"
  body = "{{ slurp_content }}"
}
```

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `src` | `string` | `""` | Path to the file to read and encode |

## Context Variables Set

| Variable | Description |
|----------|-------------|
| `slurp_content` | Base64-encoded content of the file |
| `slurp_encoding` | Always set to `base64` |
| `slurp_size` | File size in bytes (integer) |

## Platform Support

| Platform | Implementation |
|----------|---------------|
| Linux | Full |
| macOS | Full |
| FreeBSD | Full |

Cross-platform — uses Dart `File` APIs with no external dependencies.

## Rollback

No rollback necessary. `slurp` is a read-only operation that does not modify system state.
