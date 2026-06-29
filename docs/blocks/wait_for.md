# Wait For Block

Waits for a condition (port, host, or file path) before continuing execution.

## Usage

### Wait for a Port
```
wait_for {
  host = "10.0.0.1"
  port = 3306
  timeout = 60
}
```

### Wait for a File to Exist
```
wait_for {
  path = "/var/run/app.pid"
  timeout = 120
}
```

### Wait with Delay and Active Connection Check
```
wait_for {
  host = "db.internal"
  port = 5432
  delay = 10
  active_connection = true
}
```

### Wait for a File to Contain a Pattern
```
wait_for {
  path = "/var/log/app.log"
  search_regex = "Server started successfully"
  timeout = 300
}
```

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `host` | `string` | `""` | Hostname or IP to check (via ping) |
| `port` | `int` | `0` | TCP port to connect to (checked via socket) |
| `timeout` | `int` | `300` | Maximum time to wait in seconds |
| `delay` | `int` | `0` | Seconds to delay before starting checks |
| `active_connection` | `boolean` | `false` | Whether to check for active TCP connections |
| `path` | `string` | `""` | File path to check for existence or content match |
| `search_regex` | `string` | `""` | Regex to match against file content (requires `path`) |
| `sleep` | `boolean` | `false` | Use system sleep instead of polling |
| `exclude_hosts` | `boolean` | `false` | Exclude certain hosts from checks |

## Platform Support

| Platform | Implementation |
|----------|---------------|
| Linux | Full |
| macOS | Full |
| FreeBSD | Full |

Cross-platform. Port, host, and path checks use Configr's built-in runtime
helpers.

## Rollback

No rollback necessary. `wait_for` is a read-only polling operation that does not modify system state.
