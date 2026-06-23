# npm Package Manager Example

This example demonstrates package management using the **npm** block.

## Prerequisites

- Node.js and npm installed

## Running the Example

```bash
configr apply -n --dry-run        # preview
configr apply -n                   # execute
```

## What This Example Demonstrates

- **Global packages** — Tools installed system-wide via `npm install -g`
- **Local dependencies** — Packages installed in the current project

## npm Block Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `source` | string | `""` | Space-separated list of package names |
| `operation` | string | `"install"` | install, uninstall, upgrade, reinstall |
| `scope` | string | `"local"` | `local` or `global` installation scope |
| `skip_if_installed` | bool | `true` | Skip packages already present |
| `force` | bool | `false` | Force reinstall |

## Scope

- **local** — Installs to `node_modules/` in the current directory (`npm install`)
- **global** — Installs system-wide (`npm install -g`)
