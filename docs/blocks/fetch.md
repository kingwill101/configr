# Fetch Block

Copies a file from the target machine to the local machine. Useful for collecting logs, configuration files, or reports from remote systems during execution.

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `src` | `string` | `""` | Source path on the target machine |
| `dest` | `string` | `""` | Destination path on the local machine |
| `flat` | `boolean` | `false` | When true, copy file directly to `dest`; when false, preserve directory structure under `dest/<hostname>/` |
| `fail_on_missing` | `boolean` | `true` | When true, fail if source file does not exist; when false, silently skip |

## Examples

### Basic Fetch

```
fetch {
  src = "/var/log/nginx/error.log"
  dest = "/tmp/logs/"
}
```

### Flat Copy

```
fetch {
  src = "/etc/nginx/nginx.conf"
  dest = "/backups/nginx.conf"
  flat = "true"
}
```

### Non-fatal Fetch

```
fetch {
  src = "/var/log/app.log"
  dest = "/tmp/logs/"
  fail_on_missing = "false"
}
```

## Platform Support

| Platform | Implementation |
|----------|---------------|
| Linux | Full |
| macOS | Full |
| FreeBSD | Full |

## Rollback

Rollback is **not supported**. Fetched files are already copied to the local machine and are not removed.
