# Pamac Package Manager Example

This example demonstrates package management using the Pamac package manager on Manjaro Linux systems.

## Prerequisites

- Manjaro Linux system
- sudo privileges
- Internet connection for package downloads
- AUR support enabled in Pamac

## Running the Example

```bash
# Run the Pamac package configuration
dart run ../../../bin/main.dart apply -c config
```

## What This Example Demonstrates

### 1. Development Tools (`dev-tools`)
- Installs essential development tools: git, curl, wget, vim, nano, htop, tree, base-devel
- Uses Pamac package manager specifically
- Updates package cache before installation
- Skips already installed packages

### 2. Web Server Stack (`web-stack`)
- Installs web server components: nginx, php-fpm, mariadb, redis
- Uses official Manjaro repositories
- Does not skip already installed packages (allows upgrades)

### 3. Docker Environment (`docker-setup`)
- Installs Docker and related tools: docker, docker-compose, docker-buildx
- Starts Docker service after installation
- Includes before/after hooks for setup verification

### 4. AUR Packages (`aur-packages`)
- Installs AUR packages: google-chrome, visual-studio-code-bin, spotify
- Uses Pamac's built-in AUR support
- Demonstrates AUR package management without external helpers

### 5. Security Tools (`security-tools`)
- Installs security packages: fail2ban, ufw, clamav, rkhunter
- Updates package cache before installation
- Skips already installed packages

### 6. System Utilities (`system-utils`)
- Installs useful system tools: htop, iotop, ncdu, rsync, zip, unzip, jq, yq
- Updates package cache before installation
- Skips already installed packages

### 7. Manjaro-Specific Packages (`manjaro-packages`)
- Installs Manjaro-specific tools: manjaro-tools, mhwd, pamac-gtk, pamac-tray-applet
- Demonstrates Manjaro-specific package management

## Pamac-Specific Features

### Built-in AUR Support
- Pamac includes AUR support without external helpers
- AUR packages are handled seamlessly

### GUI Integration
- Pamac provides both CLI and GUI interfaces
- Tray applet for package updates

### Package Cache Updates
```configr
update_cache true  # Runs pamac update before operations
```

### Manjaro Tools Integration
- Integrates with Manjaro's hardware detection (mhwd)
- Supports Manjaro-specific tools and utilities

## Testing Different Scenarios

### Test AUR Package Installation
1. Ensure AUR support is enabled in Pamac
2. Run the configuration and observe AUR package handling

### Test GUI Integration
1. Install pamac-gtk and pamac-tray-applet
2. Use the GUI to manage packages

### Test Hardware Detection
1. Install mhwd and manjaro-tools
2. Use hardware detection tools

## Expected Results

After running the configuration:
- Packages installed via Pamac
- Package cache updated
- AUR packages installed (if AUR enabled)
- Services started (Docker)
- Manjaro-specific tools installed

## Cleanup

To remove packages installed by this example:

```bash
# Remove development tools
sudo pamac remove git curl wget vim nano htop tree base-devel

# Remove web stack
sudo pamac remove nginx php-fpm mariadb redis

# Remove Docker
sudo pamac remove docker docker-compose docker-buildx

# Remove AUR packages
sudo pamac remove google-chrome visual-studio-code-bin spotify

# Remove security tools
sudo pamac remove fail2ban ufw clamav rkhunter

# Remove system utilities
sudo pamac remove htop iotop ncdu rsync zip unzip jq yq

# Remove Manjaro packages
sudo pamac remove manjaro-tools mhwd pamac-gtk pamac-tray-applet
```

## Pamac-Specific Notes

- Requires sudo privileges for all operations
- AUR support must be enabled in Pamac settings
- GUI integration provides visual feedback
- Use `pamac list` to list installed packages
- Use `pamac search` to search for packages
- Pamac handles dependency resolution automatically
- Consider using `--no-confirm` for automated installations
- Hardware detection tools (mhwd) are Manjaro-specific
