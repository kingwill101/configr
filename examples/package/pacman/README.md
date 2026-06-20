# Pacman Package Manager Example

This example demonstrates package management using the Pacman package manager on Arch Linux systems.

## Prerequisites

- Arch Linux system
- sudo privileges
- Internet connection for package downloads
- AUR helper (yay or paru) for AUR packages

## Running the Example

```bash
# Run the Pacman package configuration
dart run ../../../bin/main.dart apply -c config
```

## What This Example Demonstrates

### 1. Development Tools (`dev-tools`)
- Installs essential development tools: git, curl, wget, vim, nano, htop, tree, base-devel
- Uses Pacman package manager specifically
- Updates package cache before installation
- Skips already installed packages

### 2. Web Server Stack (`web-stack`)
- Installs web server components: nginx, php-fpm, mariadb, redis
- Uses official Arch repositories
- Does not skip already installed packages (allows upgrades)

### 3. Docker Environment (`docker-setup`)
- Installs Docker and related tools: docker, docker-compose, docker-buildx
- Starts Docker service after installation
- Includes before/after hooks for setup verification

### 4. AUR Packages (`aur-packages`)
- Installs AUR packages: yay, google-chrome, visual-studio-code-bin
- Requires yay or paru AUR helper to be available
- Demonstrates AUR package management

### 5. Security Tools (`security-tools`)
- Installs security packages: fail2ban, ufw, clamav, rkhunter
- Updates package cache before installation
- Skips already installed packages

### 6. System Utilities (`system-utils`)
- Installs useful system tools: htop, iotop, ncdu, rsync, zip, unzip, jq, yq
- Updates package cache before installation
- Skips already installed packages

### 7. Multimedia (`multimedia`)
- Installs gaming and multimedia packages: steam, vlc, gimp, krita, obs-studio
- Demonstrates multimedia package installation

## Pacman-Specific Features

### Package Cache Updates
```configr
update_cache true  # Runs pacman -Sy before operations
```

### AUR Integration
- AUR packages are handled through yay or paru
- Requires AUR helper to be installed first

### Fast Package Management
- Pacman is known for its speed
- Minimal package cache updates

## Testing Different Scenarios

### Test AUR Package Installation
1. Ensure yay or paru is installed
2. Run the configuration and observe AUR package handling

### Test Package Cache Updates
1. Set `update_cache false` to skip cache updates
2. Compare behavior with cache updates enabled

### Test System Package Installation
1. Install system packages without AUR dependencies
2. Observe fast installation times

## Expected Results

After running the configuration:
- Packages installed via Pacman
- Package cache updated
- AUR packages installed (if helper available)
- Services started (Docker)
- Fast installation times

## Cleanup

To remove packages installed by this example:

```bash
# Remove development tools
sudo pacman -R git curl wget vim nano htop tree base-devel

# Remove web stack
sudo pacman -R nginx php-fpm mariadb redis

# Remove Docker
sudo pacman -R docker docker-compose docker-buildx

# Remove AUR packages
yay -R google-chrome visual-studio-code-bin

# Remove security tools
sudo pacman -R fail2ban ufw clamav rkhunter

# Remove system utilities
sudo pacman -R htop iotop ncdu rsync zip unzip jq yq

# Remove multimedia
sudo pacman -R steam vlc gimp krita obs-studio
```

## Pacman-Specific Notes

- Requires sudo privileges for all operations
- Package cache updates are typically very fast
- AUR packages require yay or paru AUR helper
- Use `pacman -Q` to list installed packages
- Use `yay -Q` to list AUR packages
- Pacman handles dependency resolution automatically
- Consider using `--noconfirm` for automated installations
