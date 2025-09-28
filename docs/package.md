# Package Module

The package module provides multi-platform package management capabilities, supporting various package managers across different operating systems with automatic detection and unified configuration.

## Features

- **Multi-Platform Support**: Automatic detection and support for apt, pacman, pamac, yum, dnf, zypper, brew, choco, winget
- **Package Operations**: Install, uninstall, upgrade, and reinstall packages
- **Version Management**: Specify exact package versions for installation
- **Repository Management**: Add custom repositories for package sources
- **Cache Management**: Automatic package cache updates
- **Smart Skipping**: Skip already installed packages when appropriate
- **Comprehensive Statistics**: Track packages processed, skipped, and errors encountered
- **Privilege Escalation**: Automatic privilege escalation for system package operations

## Configuration

### Basic Package Installation

```configr
resources {
  resource {
    id "install-tools"
    source "/tmp"
    destination "/tmp"
    
    actions {
      package {
        packages ["vim", "git", "curl"]
        operation "install"
        package_manager "auto"
        update_cache true
        skip_if_installed true
      }
    }
  }
}
```

### Advanced Package Management

```configr
resources {
  resource {
    id "advanced-packages"
    source "/tmp"
    destination "/tmp"
    
    actions {
      package {
        packages ["nginx", "postgresql", "redis"]
        package_versions {
          nginx "1.18.0"
          postgresql "13.0"
        }
        operation "install"
        package_manager "apt"
        repositories ["ppa:nginx/stable"]
        force false
        update_cache true
        skip_if_installed false
      }
    }
  }
}
```

### Package Upgrades

```configr
resources {
  resource {
    id "upgrade-packages"
    source "/tmp"
    destination "/tmp"
    
    actions {
      package {
        packages ["vim", "git"]
        package_versions {
          vim "2.1.0"
          git "2.40.0"
        }
        operation "upgrade"
        package_manager "auto"
      }
    }
  }
}
```

### Package Removal

```configr
resources {
  resource {
    id "remove-packages"
    source "/tmp"
    destination "/tmp"
    
    actions {
      package {
        packages ["old-package", "unused-tool"]
        operation "uninstall"
        package_manager "auto"
        skip_if_installed true
      }
    }
  }
}
```

## Configuration Options

### Package Manager

Controls which package manager to use:

- `auto` (default): Automatically detect the appropriate package manager
- `apt`: Use APT package manager (Debian/Ubuntu)
- `pacman`: Use Pacman package manager (Arch Linux)
- `pamac`: Use Pamac package manager (Manjaro)
- `npm`: Use npm package manager (Node.js packages)
- `yum`: Use YUM package manager (RHEL/CentOS)
- `dnf`: Use DNF package manager (Fedora)
- `zypper`: Use Zypper package manager (openSUSE)
- `brew`: Use Homebrew package manager (macOS)
- `choco`: Use Chocolatey package manager (Windows)
- `winget`: Use Windows Package Manager (Windows)

### Package Operations

- `install` (default): Install packages
- `uninstall`: Remove packages
- `upgrade`: Upgrade packages to newer versions
- `reinstall`: Uninstall and reinstall packages

### Package Configuration

- `packages`: List of package names to manage
- `package_versions`: Map of package names to specific versions
- `repositories`: List of additional repositories to add
- `force`: Force operations even if packages are already in desired state
- `update_cache`: Update package cache before operations (default: true)
- `skip_if_installed`: Skip packages that are already installed (default: true)

## Examples

### Development Environment Setup

```configr
resources {
  resource {
    id "dev-environment"
    source "/tmp"
    destination "/tmp"
    
    actions {
      package {
        packages ["git", "curl", "wget", "vim", "nano", "htop", "tree"]
        operation "install"
        package_manager "auto"
        update_cache true
        skip_if_installed true
      }
    }
  }
}
```

### Web Server Stack

```configr
resources {
  resource {
    id "web-stack"
    source "/tmp"
    destination "/tmp"
    
    actions {
      package {
        packages ["nginx", "php-fpm", "mysql-server", "redis-server"]
        package_versions {
          nginx "1.18.0"
          php-fpm "8.1"
        }
        operation "install"
        package_manager "apt"
        repositories ["ppa:ondrej/php"]
        update_cache true
      }
    }
  }
}
```

### Docker Environment

```configr
resources {
  resource {
    id "docker-setup"
    source "/tmp"
    destination "/tmp"
    
    actions {
      package {
        packages ["docker.io", "docker-compose", "docker-doc"]
        operation "install"
        package_manager "apt"
        repositories ["https://download.docker.com/linux/ubuntu"]
        update_cache true
      }
    }
  }
}
```

### System Cleanup

```configr
resources {
  resource {
    id "system-cleanup"
    source "/tmp"
    destination "/tmp"
    
    actions {
      package {
        packages ["old-package", "unused-tool", "deprecated-app"]
        operation "uninstall"
        package_manager "auto"
        skip_if_installed true
      }
    }
  }
}
```

### Package Reinstallation

```configr
resources {
  resource {
    id "fix-corrupted-packages"
    source "/tmp"
    destination "/tmp"
    
    actions {
      package {
        packages ["corrupted-package", "broken-tool"]
        operation "reinstall"
        package_manager "auto"
        force true
      }
    }
  }
}
```

## Supported Package Managers

### Linux Distributions

#### Debian/Ubuntu (APT)
- **Manager**: `apt`
- **Commands**: `apt-get`, `dpkg`
- **Features**: Version constraints, repository management, cache updates

#### Arch Linux (Pacman)
- **Manager**: `pacman`
- **Commands**: `pacman`
- **Features**: AUR support, dependency resolution

#### Manjaro (Pamac)
- **Manager**: `pamac`
- **Commands**: `pamac`
- **Features**: AUR integration, GUI support

#### RHEL/CentOS (YUM)
- **Manager**: `yum`
- **Commands**: `yum`
- **Features**: RPM package management, repository support

#### Fedora (DNF)
- **Manager**: `dnf`
- **Commands**: `dnf`
- **Features**: Modern YUM replacement, better dependency resolution

#### openSUSE (Zypper)
- **Manager**: `zypper`
- **Commands**: `zypper`
- **Features**: RPM package management, repository management

### Node.js

#### npm
- **Manager**: `npm`
- **Commands**: `npm`
- **Features**: Node.js package management, global/local installation, version management

### macOS

#### Homebrew
- **Manager**: `brew`
- **Commands**: `brew`
- **Features**: Formula management, cask support

### Windows

#### Chocolatey
- **Manager**: `choco`
- **Commands**: `choco`
- **Features**: Windows package management, PowerShell integration

#### Windows Package Manager
- **Manager**: `winget`
- **Commands**: `winget`
- **Features**: Microsoft's official package manager

## Error Handling

The package module provides comprehensive error handling:

- **Missing Packages**: Validates that packages are specified
- **Unsupported Operations**: Handles invalid operation types
- **Package Manager Detection**: Gracefully handles unsupported systems
- **Privilege Issues**: Automatic privilege escalation with proper error handling
- **Network Issues**: Handles repository and cache update failures
- **Statistics Tracking**: Tracks errors encountered during operations

## Rollback Considerations

**Important**: The package module has limited rollback capabilities because it doesn't track the original state of packages before operations. The rollback operation will:

- Log the package operation results for manual review
- Provide information about what was changed
- Not automatically restore original package states

For critical operations, consider:
- Creating system snapshots before package operations
- Using version control for configuration files
- Implementing your own backup strategy
- Testing package operations in isolated environments

## Performance Considerations

- **Cache Updates**: Updating package caches can be time-consuming
- **Network Operations**: Package downloads depend on network speed
- **Privilege Escalation**: May require user interaction for sudo prompts
- **Large Package Lists**: Processing many packages may take time
- **Repository Management**: Adding repositories may require additional time

## Best Practices

1. **Test First**: Always test package operations in isolated environments
2. **Use Specific Versions**: Pin package versions for reproducible environments
3. **Update Caches**: Keep package caches updated for latest package information
4. **Monitor Results**: Check package operation statistics and logs
5. **Privilege Management**: Ensure proper sudo/administrator access
6. **Repository Security**: Only add trusted repositories
7. **Backup Strategy**: Create system backups before major package operations

## Security Considerations

- **Privilege Escalation**: Package operations require elevated privileges
- **Repository Trust**: Only use trusted package repositories
- **Package Verification**: Verify package signatures when possible
- **Network Security**: Ensure secure connections for package downloads
- **System Integrity**: Monitor for unauthorized package installations

## Troubleshooting

### Common Issues

1. **Permission Denied**
   - Ensure proper sudo/administrator access
   - Check privilege escalation configuration
   - Verify user permissions for package operations

2. **Package Manager Not Found**
   - Verify the system has a supported package manager
   - Check if package manager commands are in PATH
   - Consider specifying package manager explicitly

3. **Package Not Found**
   - Verify package names are correct
   - Check if repositories are properly configured
   - Update package cache to refresh package lists

4. **Version Conflicts**
   - Check for conflicting package versions
   - Verify repository priorities
   - Consider using force option for conflicts

5. **Network Issues**
   - Check internet connectivity
   - Verify repository URLs are accessible
   - Consider using local package caches

### Debug Information

The package module provides detailed logging and statistics:
- Packages processed count
- Packages skipped count
- Errors encountered count
- Package operation results with versions
- Detailed error messages in logs
- Package manager detection information

## Limitations

- **Platform Support**: Limited to supported package managers and operating systems
- **Repository Management**: Basic repository support (advanced features may vary by package manager)
- **Rollback**: Cannot fully restore original package states
- **Dependency Resolution**: Relies on package manager's dependency resolution
- **Network Dependency**: Requires internet connectivity for most operations
- **Privilege Requirements**: Requires elevated privileges for system package operations
