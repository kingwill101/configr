# Systemd Block

Manages systemd services and creates/edits service unit files with full rollback support.

## Usage

### Enable/Disable Service
```
systemd {
  source = "docker"
  operation = "enable"
}

systemd {
  source = "docker"
  operation = "disable"
}
```

### Start/Stop/Restart Service
```
systemd {
  source = "nginx"
  operation = "start"
}

systemd {
  source = "nginx"
  operation = "stop"
}

systemd {
  source = "nginx"
  operation = "restart"
}
```

### Create Service Unit
```
systemd {
  source = "my-app"
  operation = "create"
  description = "My Application Service"
  exec_start = "/usr/bin/my-app --config /etc/my-app/config.yaml"
  restart_policy = "always"
  user = "myapp"
  group = "myapp"
  wanted_by = "multi-user.target"
  environment = "LOG_LEVEL=info,DEBUG=false"
}
```

### User Service
```
systemd {
  source = "my-user-service"
  operation = "create"
  service_type = "service"
  user_service = true
  exec_start = "/home/user/.local/bin/script.sh"
  wanted_by = "default.target"
}
```

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `source` | `string` (required) | - | Service name |
| `operation` | `string` | `"enable"` | `enable`, `disable`, `start`, `stop`, `restart`, `reload`, `create`, `edit`, `remove` |
| `service_type` | `string` | `"service"` | Unit type: `service`, `timer`, `socket`, `path`, `mount` |
| `user_service` | `boolean` | `false` | Create/manage user-level service |
| `description` | `string` | `null` | Unit description (for create) |
| `exec_start` | `string` | `null` | Command to start service |
| `exec_start_pre` | `string` | `null` | Pre-start command |
| `exec_start_post` | `string` | `null` | Post-start command |
| `exec_stop` | `string` | `null` | Stop command |
| `exec_reload` | `string` | `null` | Reload command |
| `restart_policy` | `string` | `null` | `always`, `on-failure`, `never` |
| `user` | `string` | `null` | Run as user |
| `group` | `string` | `null` | Run as group |
| `working_directory` | `string` | `null` | Working directory |
| `environment` | `string` | - | KEY=VALUE pairs (comma-separated) |
| `wanted_by` | `string` | `null` | Target to enable service for |
| `overwrite` | `boolean` | `true` | Overwrite existing unit file |
| `validate_unit` | `boolean` | `true` | Run `systemd-analyze verify` on unit |
| `require_privilege_escalation` | `boolean` | `false` | Require sudo for systemctl |

## Operations

### Service Management
- `enable` — Enable service to start on boot
- `disable` — Disable service from starting on boot
- `start` — Start service now
- `stop` — Stop service
- `restart` — Restart service
- `reload` — Reload service configuration

### Unit File Management
- `create` — Create new service unit file
- `edit` — Modify existing service unit file
- `remove` — Delete service unit file and stop/disable service

## Rollback

- Service enable → rollback to disable
- Service disable → rollback to enable
- Service start → rollback to stop
- Service stop → rollback to start
- Unit create → restore previous content or delete
- Unit edit → restore previous content
- Unit remove → restore deleted content

## Platform Support

| Platform | Implementation |
|----------|---------------|
| Linux | Full |
| macOS | Not supported |
| FreeBSD | Not supported |
| Windows | Not supported |
