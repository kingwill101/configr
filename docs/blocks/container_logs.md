# Container Logs Block

The `container_logs` block captures Docker logs from a container.

```i3
container_logs {
  container = "configr-nginx"
  tail = 50
  timestamps = true
}
```

## Properties

| Property | Default | Description |
|----------|---------|-------------|
| `container` | required | Container name |
| `tail` | `100` | Number of log lines to fetch |
| `follow` | `false` | Pass `--follow` to `docker logs` |
| `timestamps` | `false` | Pass `--timestamps` to `docker logs` |

`container_logs` is observational and has no rollback action.

