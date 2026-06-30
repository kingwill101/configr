# Package Manager Examples

This directory contains examples demonstrating package management capabilities across different package managers supported by Configr.

## Supported Package Managers

### System Package Managers
- **[APT](apt/)** — Debian/Ubuntu package management
- **[Pacman](pacman/)** — Arch Linux package management
- **[Pamac](pacman/pamac/)** — Manjaro Linux package management
- **[DNF](dnf/)** — Fedora / RHEL 8+ package management
- **[YUM](yum/)** — RHEL / CentOS 7 package management
- **[Flatpak](flatpak/)** — Cross-distribution sandboxed apps
- **[Snap](snap/)** — Ubuntu / cross-distribution snaps

### Application Package Managers
- **[Brew](brew/)** — macOS / Linux Homebrew
- **[NPM](npm/)** — Node.js package management
- **[Pip](pip/)** — Python package management
- **[Docker](docker/)** — Container image management

## Quick Start

Choose the package manager example that matches your system:

```bash
# For Debian/Ubuntu systems
cd apt && dart run ../../../bin/configr.dart apply -c config

# For Arch Linux systems
cd pacman && dart run ../../../bin/configr.dart apply -c config

# For Fedora / RHEL 8+
cd dnf && dart run ../../../bin/configr.dart apply -c config

# For RHEL / CentOS 7
cd yum && dart run ../../../bin/configr.dart apply -c config

# For macOS / Linux Homebrew
cd brew && dart run ../../../bin/configr.dart apply -c config

# For Node.js development
cd npm && dart run ../../../bin/configr.dart apply -c config

# For Python development
cd pip && dart run ../../../bin/configr.dart apply -c config

# For Docker container images
cd docker && dart run ../../../bin/configr.dart apply -c config

# For Flatpak apps
cd flatpak && dart run ../../../bin/configr.dart apply -c config

# For Snap apps
cd snap && dart run ../../../bin/configr.dart apply -c config
```

## Package Manager Comparison

| Package Manager | Platform | Privileges | Cache Updates |
|----------------|----------|------------|---------------|
| APT | Debian/Ubuntu | sudo required | Yes |
| Pacman | Arch Linux | sudo required | Yes |
| Pamac | Manjaro | sudo required | Yes |
| DNF | Fedora / RHEL 8+ | sudo required | Yes |
| YUM | RHEL / CentOS 7 | sudo required | Yes |
| Flatpak | Linux | user | Yes |
| Snap | Linux | sudo required | No |
| Brew | macOS / Linux | user (formulae) | Yes |
| NPM | Cross-platform | user (local) | No |
| Pip | Cross-platform | user | No |
| Docker | Linux | docker group | No |

## Common Features

All package manager blocks demonstrate:

- **Package Installation** — Installing packages
- **Package Upgrades** — Upgrading existing packages
- **Package Removal** — Uninstalling packages safely
- **Package Reinstallation** — Repairing corrupted packages
- **Cache Management** — Updating package caches (where applicable)
- **Error Handling** — Graceful handling of package management errors
- **Statistics Tracking** — Monitoring packages processed, skipped, and errors

## Per-Manager Block Syntax

Each package manager has its own block type using the manager's name:

```configr
apt {
  source = "git curl wget"
  operation = "install"
  update_cache = true
  skip_if_installed = true
}
```

### Package Operations

```configr
operation "install"       # Install packages (default)
operation "upgrade"       # Upgrade existing packages
operation "uninstall"     # Remove packages
operation "reinstall"     # Reinstall packages
```

## Safety Considerations

⚠️ **Important**: Package management examples will modify your system by installing, upgrading, or removing packages. Only run these examples on systems where you have permission to make these changes.

### Before Running Examples

1. **Backup your system** — Create system backups before running package operations
2. **Test in isolated environments** — Use virtual machines or containers for testing
3. **Review configurations** — Check package lists before running
4. **Use dry-run first** — Always preview with `--dry-run` before executing

### Platform-Specific Warnings

- **Linux system managers** (APT, Pacman, DNF, YUM): Require sudo privileges
- **Snap**: Requires sudo privileges
- **Docker**: Requires Docker service running and user in docker group
- **Brew, NPM, Pip, Flatpak**: Can run as user (no sudo required for most operations)

## Troubleshooting

### Common Issues

1. **Permission Denied**
   - Ensure you have required privileges for the package manager
   - Check that Docker service is running for Docker examples

2. **Package Not Found**
   - Verify package names are correct for your platform/manager
   - Check if repositories are properly configured

### Getting Help

- Check the individual README files in each package manager directory
- Review the main documentation
- Run with `--dry-run` to preview changes without executing

## Contributing

To add support for new package managers:

1. Create a new subdirectory for the package manager
2. Add a `config` file with block examples
3. Create a `README.md` with usage instructions
4. Update this main README to include the new manager

## Examples Overview

Each package manager example includes:

- **Configuration file** (`config`) — Example blocks demonstrating package management
- **README.md** — Detailed documentation and usage instructions

Choose the example that matches your system and requirements, then follow the specific instructions in that directory's README.
