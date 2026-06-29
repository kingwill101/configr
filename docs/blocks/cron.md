# Cron Block

Manages cron jobs on Linux systems. Creates, updates, and removes cron entries in `/etc/cron.d` files or individual user crontabs.

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `name` | `string` | `""` | Unique identifier for the cron job (appended as comment) |
| `job` | `string` | `""` | Command to execute |
| `minute` | `string` | `"*"` | Minute field (`0-59`, `*`, `*/N`) |
| `hour` | `string` | `"*"` | Hour field (`0-23`, `*`, `*/N`) |
| `day` | `string` | `"*"` | Day of month field (`1-31`, `*`) |
| `month` | `string` | `"*"` | Month field (`1-12`, `*`) |
| `weekday` | `string` | `"*"` | Day of week field (`0-7`, `*`) |
| `disabled` | `boolean` | `false` | Comment out the cron entry instead of removing it |
| `state` | `string` | `"present"` | `present` to add/update, `absent` to remove |
| `user` | `string` | `""` | User whose crontab to manage (defaults to `root`) |
| `cron_file` | `string` | `""` | Path to a crontab file in `/etc/cron.d` instead of user crontab |

## Examples

### Daily Backup

```
cron {
  name = "daily-backup"
  job = "/usr/local/bin/backup.sh"
  minute = "0"
  hour = "2"
}
```

### Every Hour

```
cron {
  name = "hourly-check"
  job = "/usr/local/bin/healthcheck.sh"
  minute = "0"
}
```

### Remove a Cron Job

```
cron {
  name = "old-job"
  job = "/usr/local/bin/old.sh"
  state = "absent"
}
```

## Platform Support

| Platform | Implementation |
|----------|---------------|
| Linux | Full |
| macOS | Not supported |
| FreeBSD | Not supported |

## Rollback

Rollback is **not supported**. Cron job changes are not automatically reverted.
