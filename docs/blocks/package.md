# Package Management

Configr supports 11 package managers via dedicated per-manager blocks. Each block type shares common properties while offering manager-specific features.

## Quick Reference

| Block | Manager | Platform |
|-------|---------|----------|
| [`apt`](#apt) | APT | Debian / Ubuntu |
| [`brew`](#brew) | Homebrew | macOS, Linux |
| [`dnf`](#dnf) | DNF | Fedora / RHEL 8+ |
| [`docker`](#docker) | Docker | Linux |
| [`flatpak`](#flatpak) | Flatpak | Linux |
| [`npm`](#npm) | npm | Cross-platform |
| [`pacman`](#pacman) | Pacman | Arch Linux |
| [`pamac`](#pamac) | Pamac | Manjaro |
| [`pip`](#pip) | pip | Cross-platform |
| [`snap`](#snap) | Snap | Linux |
| [`yum`](#yum) | YUM | RHEL / CentOS 7 |

---

## Common Properties

All package manager blocks support these properties:

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `source` | string | `""` | Space-separated list of package names (also `packages`) |
| `operation` | string | `"install"` | `install`, `uninstall`, `upgrade`, `reinstall` |
| `scope` | string | `"local"` | `local` or `global` installation scope |
| `update_cache` | bool | `true` | Update package cache before operations |
| `skip_if_installed` | bool | `true` | Skip packages already installed |
| `force` | bool | `false` | Force operation even on errors |
| `repositories` | list | `[]` | Additional repository sources |

### Operation Values

- **`install`** — Install packages (default)
- **`uninstall`** — Remove packages
- **`upgrade`** — Upgrade packages to latest versions
- **`reinstall`** — Uninstall then reinstall packages

### Package Names

Packages are specified as a space-separated string in `source`:

```configr
apt {
  source = "git curl wget vim"
  operation = "install"
}
```

The alias `packages` also works (from the block variable syntax).

---

## apt

Debian / Ubuntu package management.

**Manager**: APT (`apt-get`, `dpkg`)  
**Privileges**: sudo required  
**Cache**: `apt update`  
**Repositories**: `add-apt-repository`

```configr
apt {
  source = "nginx php-fpm mysql-server redis-server"
  operation = "install"
  repositories = ["ppa:ondrej/php"]
  update_cache = true
  skip_if_installed = true
}
```

### apt-Specific Notes

- `update_cache` runs `apt update` before operations
- `repositories` calls `add-apt-repository -y <url>`
- All installations are system-wide (global scope)

---

## brew

Homebrew package management for macOS and Linux.

**Manager**: Homebrew (`brew`)  
**Privileges**: User (no sudo for most operations)  
**Cache**: `brew update` (via `update_cache`)  
**Repositories**: `brew tap`

```configr
brew {
  source = "git curl wget htop tree jq yq"
  operation = "install"
  update_cache = true
  skip_if_installed = true
}
```

### brew-Specific Notes

- `repositories` calls `brew tap <url>` for third-party taps
- Scope `global` maps to `brew install` (formulae are always system-wide)
- Cask applications are installed via `brew install --cask` — include cask names in `source`

---

## dnf

DNF package management for Fedora / RHEL 8+.

**Manager**: DNF (`dnf`)  
**Privileges**: sudo required  
**Cache**: `dnf check-update`

```configr
dnf {
  source = "nginx php-fpm mariadb-server redis"
  operation = "install"
  update_cache = true
  skip_if_installed = true
}
```

---

## docker

Docker container image management.

**Manager**: Docker (`docker`)  
**Privileges**: Docker group / sudo  
**Cache**: None  
**Operation**: `install` maps to `docker pull`

```configr
docker {
  source = "nginx:alpine redis:alpine postgres:16-alpine"
  operation = "install"
  skip_if_installed = true
}
```

### docker-Specific Notes

- Images use standard Docker tag format: `name:tag`
- `skip_if_installed` checks if an image exists locally (`docker images -q`)
- Only `install`, `uninstall`, and `reinstall` are supported

---

## flatpak

Cross-distribution sandboxed application management.

**Manager**: Flatpak (`flatpak`)  
**Privileges**: User (--user) or system  
**Cache**: None  
**Scope**: Supports both `local` (--user) and `global` (--system)

```configr
flatpak {
  source = "org.mozilla.firefox org.gimp.GIMP org.videolan.VLC"
  operation = "install"
  scope = "local"
  skip_if_installed = true
}
```

### flatpak-Specific Notes

- Use fully-qualified application IDs (e.g. `org.mozilla.firefox`)
- `scope = "local"` installs per-user (`flatpak install --user`)
- `scope = "global"` installs system-wide (`flatpak install --system`)
- Flatpak has the richest capability set alongside npm

---

## npm

Node.js package management.

**Manager**: npm (`npm`)  
**Privileges**: User  
**Cache**: None  
**Scope**: Supports both `local` and `global` installation

```configr
# Global tools
npm {
  source = "typescript prettier eslint nodemon"
  operation = "install"
  scope = "global"
  skip_if_installed = true
}

# Local project dependencies
npm {
  source = "express lodash axios"
  operation = "install"
  scope = "local"
  skip_if_installed = true
}
```

### npm-Specific Notes

- `scope = "local"` installs to `node_modules/` in current directory (`npm install`)
- `scope = "global"` installs system-wide (`npm install -g`)
- npm is the only manager with full global/local context separation

---

## pacman

Arch Linux package management.

**Manager**: Pacman (`pacman`)  
**Privileges**: sudo required  
**Cache**: `pacman -Sy`

```configr
pacman {
  source = "git curl wget vim nano htop tree base-devel"
  operation = "install"
  update_cache = true
  skip_if_installed = true
}
```

---

## pamac

Manjaro Linux package management (Pamac wrapper around pacman).

**Manager**: Pamac (`pamac`)  
**Privileges**: sudo required  
**Cache**: Pamac handles automatically  
**AUR**: Built-in AUR support

```configr
pamac {
  source = "google-chrome visual-studio-code-bin spotify"
  operation = "install"
  update_cache = true
  skip_if_installed = true
}
```

### pamac-Specific Notes

- AUR packages can be included directly in `source` — Pamac handles building and installing automatically
- Pamac is the Manjaro-specific alternative to raw pacman

---

## pip

Python package management.

**Manager**: pip (`pip3`)  
**Privileges**: User  
**Cache**: None

```configr
pip {
  source = "numpy pandas matplotlib scikit-learn"
  operation = "install"
  skip_if_installed = true
}
```

### pip-Specific Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `venv` | string | `null` | Create and activate a virtual environment at this path |
| `requirements` | string | `null` | Install from a requirements.txt file after packages |

```configr
pip {
  source = "flask django"
  operation = "install"
  venv = "./venv"
  requirements = "requirements.txt"
}
```

---

## snap

Snap package management for Ubuntu and other snap-enabled Linux distributions.

**Manager**: Snap (`snap`)  
**Privileges**: sudo required  
**Cache**: None

```configr
snap {
  source = "firefox vlc gimp krita"
  operation = "install"
  skip_if_installed = true
}
```

---

## yum

YUM package management for RHEL / CentOS 7.

**Manager**: YUM (`yum`)  
**Privileges**: sudo required  
**Cache**: `yum makecache`

```configr
yum {
  source = "nginx php-fpm mariadb-server redis"
  operation = "install"
  update_cache = true
  skip_if_installed = true
}
```

> **Note**: YUM is the legacy manager for RHEL 7 and earlier. Use `dnf` for RHEL 8+.

---

## Capability Matrix

| Manager | Global Inst | Local Inst | Global/Local Context | Cache Updates | Repositories |
|---------|-------------|------------|---------------------|---------------|--------------|
| apt | ✅ | ❌ | ❌ | ✅ | ✅ |
| brew | ✅ | ❌ | ❌ | ❌¹ | ✅ |
| dnf | ❌ | ❌ | ❌ | ✅ | ❌ |
| docker | ✅ | ❌ | ❌ | ❌ | ❌ |
| flatpak | ✅ | ✅ | ✅ | ❌ | ❌ |
| npm | ✅ | ✅ | ✅ | ❌ | ❌ |
| pacman | ✅ | ❌ | ❌ | ✅ | ❌ |
| pamac | ❌ | ❌ | ❌ | ❌ | ❌ |
| pip | ❌ | ❌ | ❌ | ❌ | ❌ |
| snap | ❌ | ❌ | ❌ | ❌ | ❌ |
| yum | ❌ | ❌ | ❌ | ✅ | ❌ |

¹ Brew `update_cache` runs `brew update` via the base class but is not explicitly overridden.

---

## Examples

See [`examples/package/`](https://github.com/kingwill101/configr/tree/main/examples/package/) for runnable config files for every manager.

| Manager | Example |
|---------|---------|
| APT | [`examples/package/apt/config`](https://github.com/kingwill101/configr/tree/main/examples/package/apt/config) |
| Brew | [`examples/package/brew/config`](https://github.com/kingwill101/configr/tree/main/examples/package/brew/config) |
| DNF | [`examples/package/dnf/config`](https://github.com/kingwill101/configr/tree/main/examples/package/dnf/config) |
| Docker | [`examples/package/docker/config`](https://github.com/kingwill101/configr/tree/main/examples/package/docker/config) |
| Flatpak | [`examples/package/flatpak/config`](https://github.com/kingwill101/configr/tree/main/examples/package/flatpak/config) |
| npm | [`examples/package/npm/config`](https://github.com/kingwill101/configr/tree/main/examples/package/npm/config) |
| Pacman | [`examples/package/pacman/config`](https://github.com/kingwill101/configr/tree/main/examples/package/pacman/config) |
| Pamac | [`examples/package/pacman/pamac/config`](https://github.com/kingwill101/configr/tree/main/examples/package/pacman/pamac/config) |
| pip | [`examples/package/pip/config`](https://github.com/kingwill101/configr/tree/main/examples/package/pip/config) |
| Snap | [`examples/package/snap/config`](https://github.com/kingwill101/configr/tree/main/examples/package/snap/config) |
| YUM | [`examples/package/yum/config`](https://github.com/kingwill101/configr/tree/main/examples/package/yum/config) |
