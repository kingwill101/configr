# Package Manager Examples

This directory contains examples demonstrating package management capabilities across different package managers supported by Configr.

## Supported Package Managers

### System Package Managers
- **[APT](apt/)** - Debian/Ubuntu package management
- **[Pacman](pacman/)** - Arch Linux package management  
- **[Pamac](pamac/)** - Manjaro Linux package management
- **[Docker](docker/)** - Container package management

### Application Package Managers
- **[NPM](npm/)** - Node.js package management

## Quick Start

Choose the package manager example that matches your system:

```bash
# For Debian/Ubuntu systems
cd apt && dart run ../../../bin/main.dart apply -c config

# For Arch Linux systems
cd pacman && dart run ../../../bin/main.dart apply -c config

# For Manjaro Linux systems
cd pamac && dart run ../../../bin/main.dart apply -c config

# For Docker container management
cd docker && dart run ../../../bin/main.dart apply -c config

# For Node.js development
cd npm && dart run ../../../bin/main.dart apply -c config
```

## Package Manager Comparison

| Package Manager | Platform | Privileges | Cache Updates | AUR Support | GUI |
|----------------|----------|------------|---------------|-------------|-----|
| APT | Debian/Ubuntu | sudo required | Yes | No | No |
| Pacman | Arch Linux | sudo required | Yes | With helper | No |
| Pamac | Manjaro | sudo required | Yes | Built-in | Yes |
| Docker | Linux | sudo required | No | No | No |
| NPM | Cross-platform | None | No | No | No |

## Common Features

All package manager examples demonstrate:

- **Package Installation** - Installing packages with version constraints
- **Package Upgrades** - Upgrading existing packages to newer versions
- **Package Removal** - Uninstalling packages safely
- **Package Reinstallation** - Repairing corrupted packages
- **Cache Management** - Updating package caches (where applicable)
- **Error Handling** - Graceful handling of package management errors
- **Statistics Tracking** - Monitoring packages processed, skipped, and errors

## Configuration Options

### Package Manager Selection
```configr
package_manager "apt"     # Use specific package manager
package_manager "auto"    # Auto-detect available manager
```

### Package Operations
```configr
operation "install"       # Install packages (default)
operation "upgrade"       # Upgrade existing packages
operation "uninstall"     # Remove packages
operation "reinstall"     # Reinstall packages
```

### Version Constraints
```configr
package_versions {
  package_name "1.0.0"
  another_package "2.1.0"
}
```

### Cache Management
```configr
update_cache true         # Update package cache before operations
skip_if_installed true    # Skip already installed packages
```

## Safety Considerations

⚠️ **Important**: Package management examples will modify your system by installing, upgrading, or removing packages. Only run these examples on systems where you have permission to make these changes.

### Before Running Examples

1. **Backup your system** - Create system backups before running package operations
2. **Test in isolated environments** - Use virtual machines or containers for testing
3. **Review configurations** - Check package lists and versions before running
4. **Have rollback plans** - Know how to undo changes if needed

### Platform-Specific Warnings

- **Linux systems**: Require sudo privileges for system package managers
- **Docker**: Requires Docker service to be running
- **NPM**: Installs to user directory, no sudo required

## Troubleshooting

### Common Issues

1. **Permission Denied**
   - Ensure you have sudo privileges for system package managers
   - Check that Docker service is running for Docker examples

2. **Package Not Found**
   - Verify package names are correct for your platform
   - Check if repositories are properly configured

3. **Version Conflicts**
   - Review version constraints in configuration
   - Check for dependency conflicts

4. **Cache Issues**
   - Clear package caches if updates fail
   - Restart package manager services if needed

### Getting Help

- Check the individual README files in each package manager directory
- Review the main [Package Module documentation](../../docs/package.md)
- Check the `app.log` file for detailed error information

## Contributing

To add support for new package managers:

1. Create a new directory for the package manager
2. Add configuration examples specific to that manager
3. Create a comprehensive README with platform-specific notes
4. Update this main README to include the new manager

## Examples Overview

Each package manager example includes:

- **Configuration file** (`config`) - Main configuration demonstrating package management
- **README.md** - Detailed documentation and usage instructions
- **Additional files** - Any required files (like package.json for npm, docker-compose.yml for Docker)

Choose the example that matches your system and requirements, then follow the specific instructions in that directory's README.
