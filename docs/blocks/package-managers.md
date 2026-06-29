# Package Manager Blocks

Configr supports direct package-manager action blocks in addition to the generic
[`package`](package.md) block.

```i3
apt {
  packages = ["curl", "git"]
  operation = "install"
}

brew {
  packages = "ripgrep fd"
  operation = "install"
  update_cache = false
}
```

## Supported Blocks

| Block | Backend |
|-------|---------|
| `apt` | APT |
| `brew` | Homebrew |
| `dnf` | DNF |
| `docker` | Docker package manager adapter |
| `flatpak` | Flatpak |
| `npm` | npm |
| `pacman` | Pacman |
| `pamac` | Pamac |
| `pip` | pip |
| `snap` | Snap |
| `yum` | Yum |

## Shared Properties

| Property | Default | Description |
|----------|---------|-------------|
| `packages` | unset | Package list as a list or whitespace-separated string |
| `source` | unset | Alternative source for package names |
| `operation` | `install` | Operation passed to the package manager adapter |
| `scope` | `local` | Package scope for managers that support scopes |
| `force` | `false` | Force the operation where supported |
| `skip_if_installed` | `true` | Avoid reinstalling packages already present |
| `update_cache` | `true` | Update package cache before applying |

These blocks record installed versions in lockfile metadata when the operation
installs or reinstalls packages.

