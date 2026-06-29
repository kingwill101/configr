# Dependency Block

The `dependency` block waits for a host, network endpoint, or port state before
continuing. It is useful in multi-host runs where one host must be reachable
before another host applies dependent work.

```i3
dependency {
  from = "web-01"
  to = "db-01"
  type = "port"
  port = 5432
  timeout = 120
  interval = 5
}
```

## Properties

| Property | Default | Description |
|----------|---------|-------------|
| `host` | unset | Target hostname or address to check |
| `to` | unset | Target host name/address when `host` is not set |
| `from` | unset | Origin host label for status output |
| `type` | `network` | Check type: `network`, `ping`, or `port` |
| `check_type` | `network` | Alias for `type` |
| `port` | `0` | TCP port for `port` checks or network checks with a port |
| `timeout` | `60` | Maximum wait time in seconds |
| `delay` | `0` | Initial delay in seconds before checking |
| `interval` | `5` | Delay in seconds between attempts |
| `state` | `reachable` | Expected state: `reachable` or `unreachable` |

Either `host` or `to` must be set. `dependency` has no rollback action.

