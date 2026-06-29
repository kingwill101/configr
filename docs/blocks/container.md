# Container Block

The `container` block manages Docker containers on the current execution
backend. In local integration tests it runs against the container-local Docker
environment; in remote mode it runs Docker commands through the active remote
execution service.

```i3
container {
  image = "nginx"
  tag = "latest"
  container_name = "configr-nginx"
  state = "running"
  ports = "8080:80"
  restart_policy = "unless-stopped"
  pull = true
}
```

## Properties

| Property | Default | Description |
|----------|---------|-------------|
| `state` | `running` | `running`, `started`, `stopped`, `restarted`, or `absent` |
| `image` | required for create | Image name |
| `tag` | `latest` | Image tag |
| `container_name` | required | Docker container name |
| `ports` | unset | Comma-separated Docker port mappings |
| `volumes` | unset | Comma-separated Docker volume mappings |
| `env` | unset | Comma-separated environment assignments |
| `command` | unset | Command appended to `docker run` |
| `restart_policy` | unset | Docker restart policy |
| `network` | unset | Docker network |
| `health_check` | unset | Shell command checked after start/restart |
| `pull` | `false` | Pull the image before applying |

Rollback restores the previous running/absent state where possible.

