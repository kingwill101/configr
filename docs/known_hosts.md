# Known Hosts Block

Manages SSH known_hosts entries — adds or removes host keys from the system-wide SSH known_hosts file.

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `name` | `string` | `""` | Hostname or IP address to manage |
| `key` | `string` | `""` | SSH host key (e.g. `ssh-ed25519 AAAAC3...`) |
| `path` | `string` | `"/etc/ssh/ssh_known_hosts"` | Path to the known_hosts file |
| `hash_host` | `boolean` | `false` | Hash the hostname entry (currently stores raw hostname) |
| `state` | `string` | `present` | Whether the host key entry should be `present` or `absent` |

## Examples

### Add a Host Key

```
known_hosts {
  name = "github.com"
  key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl"
}
```

### Remove a Host Key

```
known_hosts {
  name = "old-server.example.com"
  state = "absent"
}
```

### Add to a Custom known_hosts File

```
known_hosts {
  name = "internal-server"
  key = "ssh-rsa AAAAB3NzaC1yc2EAAA..."
  path = "/home/deploy/.ssh/known_hosts"
}
```

## Platform Support

| Platform | Implementation |
|----------|---------------|
| Linux    | Full — file-based |
| macOS    | Full — file-based |
| FreeBSD  | Full — file-based |

## Rollback

No automatic rollback is performed. Removed entries are not restored.
