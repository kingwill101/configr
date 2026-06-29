# Service Block

Manages system services across init systems with platform dispatch.

## Usage

### Start and Enable a Service
```
service {
  name = "nginx"
  state = "started"
  enabled = true
}
```

### Stop a Service
```
service {
  name = "apache2"
  state = "stopped"
}
```

### Restart with Specific Init System
```
service {
  name = "sshd"
  state = "restarted"
  use = "systemd"
}
```

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `name` | `string` | `""` | Service name to manage |
| `state` | `string` | `""` | Desired service state: `started`, `stopped`, `restarted`, `reloaded` |
| `enabled` | `boolean` | `false` | Whether to enable the service at boot |
| `use` | `string` | `"auto"` | Init system to use: `auto`, `systemd`, `sysvinit`, `service`, `launchctl` |

## Platform Support

| Platform | Implementation | Commands Used |
|----------|---------------|---------------|
| Linux | Full | `systemctl`, `service`, `update-rc.d`, `chkconfig` |
| macOS | Full | `launchctl` (load/unload plists from `/Library/LaunchDaemons`) |
| FreeBSD | Full | `service`, `sysrc` |

## Rollback

The block tracks the previous state of the service. On rollback:
- If the service was **started**, it is **stopped**.
- If the service was **stopped**, it is **started**.
- **restarted** and **reloaded** states are not rolled back.
