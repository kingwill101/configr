# Docker Package Manager Example

This example demonstrates pulling container images using the **docker** block.

## Prerequisites

- Docker daemon running
- Internet connection

## Running the Example

```bash
configr apply -n --dry-run        # preview
configr apply -n                   # execute
```

## What This Example Demonstrates

- **Base images** — hello-world, alpine
- **Service images** — nginx:alpine, redis:alpine, postgres:16-alpine

## Docker Block Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `source` | string | `""` | Space-separated list of image names |
| `operation` | string | `"install"` | install maps to `docker pull` |
| `skip_if_installed` | bool | `true` | Skip images already present locally |
| `force` | bool | `false` | Force re-pull |

## Cleanup

```bash
docker rmi hello-world alpine nginx:alpine redis:alpine postgres:16-alpine
```
