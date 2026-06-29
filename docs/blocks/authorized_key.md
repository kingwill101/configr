# Authorized Key Block

Manages SSH authorized_keys entries on the target system. Supports adding, updating, and removing SSH public keys for specified users with full control over key options and file permissions.

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `user` | `string` | `""` | Username whose authorized_keys file to manage |
| `key` | `string` | `""` | SSH public key content (full key string) |
| `key_options` | `string` | `""` | Key options prepended to the key (e.g. `command="/usr/bin/rsync"`) |
| `path` | `string` | `""` | Custom path to authorized_keys file; defaults to `~/.ssh/authorized_keys` |
| `manage_dir` | `boolean` | `true` | Create and set permissions on the `.ssh` directory |
| `exclusive` | `boolean` | `false` | When true, replace all existing keys with only the specified key |
| `state` | `string` | `"present"` | `present` to ensure key exists, `absent` to remove it |

## Examples

### Add a Key

```
authorized_key {
  user = "deploy"
  key = "ssh-ed25519 AAAAC3... user@host"
}
```

### Add a Key with Options

```
authorized_key {
  user = "admin"
  key = "ssh-rsa AAAAB3..."
  key_options = "command=\"/usr/bin/rsync\",no-agent-forwarding"
}
```

### Remove a Key

```
authorized_key {
  user = "olduser"
  key = "ssh-ed25519 AAAAC3... old@host"
  state = "absent"
}
```

## Platform Support

| Platform | Implementation |
|----------|---------------|
| Linux | Full |
| macOS | Full |

## Rollback

Rollback is **not supported**. Authorized key changes are not automatically reverted. Manual intervention is required to restore previous authorized_keys content.
