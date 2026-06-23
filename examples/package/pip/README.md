# pip Package Manager Example

This example demonstrates package management using the **pip** block for Python packages.

## Prerequisites

- Python 3 and pip installed

## Running the Example

```bash
configr apply -n --dry-run        # preview
configr apply -n                   # execute
```

## What This Example Demonstrates

- **Data science** — numpy, pandas, matplotlib, scikit-learn
- **Web development** — flask, django, requests, beautifulsoup4
- **Dev tools** — pytest, black, flake8, mypy

## pip Block Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `source` | string | `""` | Space-separated list of package names |
| `operation` | string | `"install"` | install, uninstall, upgrade, reinstall |
| `skip_if_installed` | bool | `true` | Skip packages already present |
| `force` | bool | `false` | Force reinstall |

## Cleanup

```bash
pip uninstall numpy pandas matplotlib scikit-learn flask django requests beautifulsoup4 pytest black flake8 mypy -y
```
