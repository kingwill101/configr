# Package Module

The package module provides multi-platform package management capabilities, supporting various package managers across different operating systems with automatic detection and unified configuration.

## Features

- **Multi-Platform Support**: Automatic detection and support for apt, pacman, pamac, npm, docker
- **Package Operations**: Install, uninstall, upgrade, and reinstall packages
- **Version Management**: Specify exact package versions for installation
- **Global/Local Installation**: Support for both global and local package installation (npm)
- **Repository Management**: Add custom repositories for package sources
- **Cache Management**: Automatic package cache updates
- **Smart Skipping**: Skip already installed packages when appropriate
- **Comprehensive Statistics**: Track packages processed, skipped, and errors encountered
- **Enhanced Rollback**: Full rollback support with package uninstallation
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

### Global vs Local Installation (npm)

```configr
resources {
  resource {
    id "global-npm-packages"
    source "/tmp"
    destination "/tmp"
    
    actions {
      package {
        packages ["typescript", "eslint", "prettier"]
        package_versions {
          typescript "5.0.0"
          eslint "8.0.0"
        }
        operation "install"
        package_manager "npm"
        install_globally true
        update_cache false
        skip_if_installed true
      }
    }
  }
}

resources {
  resource {
    id "local-npm-packages"
    source "/tmp"
    destination "/tmp"
    
    actions {
      package {
        packages ["express", "cors", "helmet"]
        package_versions {
          express "4.18.0"
          cors "2.8.5"
        }
        operation "install"
        package_manager "npm"
        install_globally false
        update_cache false
        skip_if_installed true
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
- `docker`: Use Docker for container images

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
- `install_globally`: Install packages globally vs locally (npm only, default: true)

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

### Docker Images

```configr
resources {
  resource {
    id "docker-images"
    source "/tmp"
    destination "/tmp"
    
    actions {
      package {
        packages ["nginx", "postgres", "redis"]
        package_versions {
          nginx "1.21"
          postgres "13"
          redis "6.2"
        }
        operation "install"
        package_manager "docker"
        update_cache false
        skip_if_installed true
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
- **Capabilities**: Global installation only (system-wide packages)

#### Arch Linux (Pacman)
- **Manager**: `pacman`
- **Commands**: `pacman`
- **Features**: AUR support, dependency resolution
- **Capabilities**: Global installation only (system-wide packages)

#### Manjaro (Pamac)
- **Manager**: `pamac`
- **Commands**: `pamac`
- **Features**: AUR integration, GUI support, version locking
- **Capabilities**: Global installation, version locking

### Node.js

#### npm
- **Manager**: `npm`
- **Commands**: `npm`
- **Features**: Node.js package management, global/local installation, version management
- **Capabilities**: Global installation, local installation, global/local context management
- **Configuration**: Use `install_globally: true/false` to control installation scope

### Containerization

#### Docker
- **Manager**: `docker`
- **Commands**: `docker`
- **Features**: Container image management, version tagging
- **Capabilities**: Global installation only (images are global)
- **Note**: Uses `package:version` format for image tags

## Package Manager Capabilities

The package management system uses a capability-based architecture where each package manager declares what operations it supports:

### Capability Types

#### GlobalInstallCapability
- **Purpose**: Supports global/system-wide package installation
- **Supported by**: All package managers (apt, pacman, pamac, npm, docker)
- **Usage**: Automatically used when `install_globally: true` or for system package managers

#### LocalInstallCapability  
- **Purpose**: Supports local/project-scoped package installation
- **Supported by**: npm only
- **Usage**: Used when `install_globally: false` for npm packages

#### GlobalLocalContextCapability
- **Purpose**: Can distinguish between global and local package contexts
- **Supported by**: npm only
- **Usage**: Enables separate checking and management of global vs local packages

#### VersionLockCapability
- **Purpose**: Can lock package versions to prevent updates
- **Supported by**: pamac only
- **Usage**: Prevents automatic package updates

### Capability Matrix

| Manager | GlobalInstall | LocalInstall | GlobalLocalContext | VersionLock |
|---------|---------------|--------------|-------------------|-------------|
| **apt** | ✅ | ❌ | ❌ | ❌ |
| **pacman** | ✅ | ❌ | ❌ | ❌ |
| **pamac** | ✅ | ❌ | ❌ | ✅ |
| **npm** | ✅ | ✅ | ✅ | ❌ |
| **docker** | ✅ | ❌ | ❌ | ❌ |

## npm-Specific Configuration

npm is the most feature-rich package manager, supporting both global and local installations:

### Global Installation (Default)
```configr
package {
  packages ["typescript", "eslint", "prettier"]
  package_manager "npm"
  install_globally true  # Default value
}
```

### Local Installation
```configr
package {
  packages ["express", "cors", "helmet"]
  package_manager "npm"
  install_globally false
}
```

### Mixed Installation
You can mix global and local installations in the same configuration by using separate resources:

```configr
resources {
  # Global tools
  resource {
    id "global-tools"
    actions {
      package {
        packages ["typescript", "eslint", "prettier"]
        package_manager "npm"
        install_globally true
      }
    }
  }
  
  # Local dependencies
  resource {
    id "local-deps"
    actions {
      package {
        packages ["express", "cors", "helmet"]
        package_manager "npm"
        install_globally false
      }
    }
  }
}
```
