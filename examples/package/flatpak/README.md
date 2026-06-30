# Flatpak Package Manager Example

This example demonstrates package management using the **flatpak** block.

## Prerequisites

- Flatpak installed and configured with Flathub remote

## Running the Example

```bash
configr apply -n --dry-run        # preview
configr apply -n                   # execute
```

## Flatpak Block Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `source` | string | `""` | Space-separated list of Flatpak app IDs |
| `operation` | string | `"install"` | install, uninstall, upgrade |
| `repository` | string | `"flathub"` | Flatpak remote repository name |
| `skip_if_installed` | bool | `true` | Skip packages already present |
| `force` | bool | `false` | Force operation |

## Cleanup

```bash
flatpak uninstall org.mozilla.firefox org.gimp.GIMP org.videolan.VLC
```
