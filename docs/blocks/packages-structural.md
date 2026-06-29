# Structural Packages Block

The top-level `packages` section builds package models in the configuration
reader. It is separate from the action block named [`package`](package.md)
and from direct package-manager action blocks such as [`apt`](package-managers.md).

```i3
packages {
  package {
    name = "ripgrep"
    manager = "apt"
    version = "latest"
    scope = "system"
  }
}
```

## Properties

| Property | Description |
|----------|-------------|
| `name` | Package name. Required |
| `manager` | Package manager name |
| `version` | Desired version metadata |
| `scope` | Package scope metadata |
| `id` | Optional identifier |
| `status` | Stored status metadata |
| `timestamp` | Stored timestamp metadata |
| `sha256` | Stored checksum metadata |

For executable package management, use [`package`](package.md) or the direct
package manager blocks documented in [Package Manager Blocks](package-managers.md).
