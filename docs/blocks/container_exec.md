# Container Exec Block

The `container_exec` block runs a command inside an existing Docker container.

```i3
container_exec {
  container = "configr-nginx"
  command = "nginx -t"
  working_dir = "/"
}
```

## Properties

| Property | Default | Description |
|----------|---------|-------------|
| `container` | required | Container name |
| `command` | required | Command to run inside the container |
| `working_dir` | unset | Working directory passed with `docker exec -w` |
| `interactive` | `false` | Pass `-i` to `docker exec` |

`container_exec` captures stdout internally and has no rollback action.

