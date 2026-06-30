# Homebrew Package Manager Example

This example demonstrates package management using the **brew** block on macOS or Linux.

## Prerequisites

- Homebrew installed (https://brew.sh)

## Running the Example

```bash
configr apply -n --dry-run        # preview
configr apply -n                   # execute
```

## What This Example Demonstrates

- **Formulae** — CLI tools and libraries (`git`, `python`, `postgresql`)
- **Casks** — GUI applications on macOS (`visual-studio-code`, `firefox`)

## Brew Block Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `source` | string | `""` | Space-separated list of formula/cask names |
| `operation` | string | `"install"` | install, uninstall, upgrade, reinstall |
| `update_cache` | bool | `true` | Run `brew update` before operations |
| `skip_if_installed` | bool | `true` | Skip packages already present |
| `force` | bool | `false` | Force operation |

## Cleanup

```bash
brew uninstall git curl wget htop tree jq yq
brew uninstall python node postgresql redis
brew uninstall --cask visual-studio-code firefox iterm2
```
