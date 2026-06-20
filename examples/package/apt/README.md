# APT Package Manager Example

This example demonstrates package management using the APT package manager on Debian/Ubuntu systems.

## Prerequisites

- Debian or Ubuntu system
- sudo privileges
- Internet connection for package downloads

## Running the Example

```bash
# Run the APT package configuration
dart run ../../../bin/main.dart apply -c config
```

## What This Example Demonstrates

### 1. Development Tools (`dev-tools`)
- Installs essential development tools: git, curl, wget, vim, nano, htop, tree, build-essential
- Uses APT package manager specifically
- Updates package cache before installation
- Skips already installed packages

### 2. Web Server Stack (`web-stack`)
- Installs web server components: nginx, php-fpm, mysql-server, redis-server
- Specifies exact versions for nginx and php-fpm
- Adds PHP repository (ppa:ondrej/php) for latest PHP versions
- Does not skip already installed packages (allows upgrades)

### 3. Docker Environment (`docker-setup`)
- Installs Docker and related tools: docker.io, docker-compose, docker-doc
- Adds Docker's official repository
- Starts Docker service after installation
- Includes before/after hooks for setup verification

### 4. Security Tools (`security-tools`)
- Installs security packages: fail2ban, ufw, clamav, rkhunter, unattended-upgrades
- Updates package cache before installation
- Skips already installed packages

### 5. System Utilities (`system-utils`)
- Installs useful system tools: htop, iotop, ncdu, rsync, zip, unzip, jq, yq
- Updates package cache before installation
- Skips already installed packages

## APT-Specific Features

### Repository Management
```configr
repositories ["ppa:ondrej/php", "https://download.docker.com/linux/ubuntu"]
```

### Package Cache Updates
```configr
update_cache true  # Runs apt update before operations
```

### Version Constraints
```configr
package_versions {
  nginx "1.18.0"
  php-fpm "8.1"
}
```

## Testing Different Scenarios

### Test Repository Addition
1. Add custom repositories to the config
2. Run the configuration and observe repository setup

### Test Version Constraints
1. Modify package versions in the config
2. Run and observe version handling

### Test Cache Updates
1. Set `update_cache false` to skip cache updates
2. Compare behavior with cache updates enabled

## Expected Results

After running the configuration:
- Packages installed via APT
- Package cache updated
- Repositories added as specified
- Version constraints applied
- Services started (Docker)

## Cleanup

To remove packages installed by this example:

```bash
# Remove development tools
sudo apt remove git curl wget vim nano htop tree build-essential

# Remove web stack
sudo apt remove nginx php-fpm mysql-server redis-server

# Remove Docker
sudo apt remove docker.io docker-compose docker-doc

# Remove security tools
sudo apt remove fail2ban ufw clamav rkhunter unattended-upgrades

# Remove system utilities
sudo apt remove htop iotop ncdu rsync zip unzip jq yq
```

## APT-Specific Notes

- Requires sudo privileges for all operations
- Package cache updates may take time on first run
- Repository GPG keys are handled automatically
- APT handles dependency resolution automatically
- Use `apt list --installed` to check installed packages
