# Package Module Example

This example demonstrates the various capabilities of the package module for multi-platform package management across different operating systems and package managers.

## Setup

This example requires:
- A supported operating system (Linux, macOS, Windows)
- A supported package manager (apt, pacman, pamac, yum, dnf, zypper, brew, choco, winget)
- Appropriate privileges for package management (sudo/administrator access)

## Running the Example

**⚠️ WARNING**: This example will attempt to install, upgrade, and manage system packages. Only run this on systems where you have permission to modify packages.

```bash
# Run the package configuration
dart run ../../bin/main.dart apply -c config
```

## What This Example Demonstrates

### 1. Development Tools Installation (`dev-tools`)
- Installs common development tools: git, curl, wget, vim, nano, htop, tree
- Uses automatic package manager detection
- Skips already installed packages
- Updates package cache before installation

### 2. Web Server Stack (`web-stack`)
- Installs web server components: nginx, php-fpm, mysql-server, redis-server
- Specifies exact versions for nginx and php-fpm
- Adds PHP repository for latest PHP versions
- Uses APT package manager specifically
- Does not skip already installed packages (allows upgrades)

### 3. Docker Environment Setup (`docker-setup`)
- Installs Docker and related tools: docker.io, docker-compose, docker-doc
- Adds Docker's official repository
- Uses APT package manager
- Skips already installed packages

### 4. Package Upgrades (`upgrade-packages`)
- Upgrades vim, git, and curl to specific versions
- Uses automatic package manager detection
- Only upgrades if packages are already installed

### 5. System Cleanup (`system-cleanup`)
- Removes unused packages: old-package, unused-tool, deprecated-app
- Uses automatic package manager detection
- Skips packages that are not installed

### 6. Package Reinstallation (`fix-packages`)
- Reinstalls potentially corrupted packages
- Uses force option to ensure reinstallation
- Updates package cache before operations

### 7. Cross-Platform Tools (`cross-platform-tools`)
- Installs tools available on multiple platforms: jq, yq, kubectl, helm
- Uses automatic package manager detection
- Demonstrates cross-platform package management

### 8. Security Tools (`security-tools`)
- Installs security-related packages: fail2ban, ufw, clamav, rkhunter
- Uses automatic package manager detection
- Skips already installed packages

## Testing Different Scenarios

### Test Package Manager Detection

1. Run with different package managers:
```bash
# Force specific package manager
dart run ../../bin/main.dart apply -c config --override package_manager=apt
```

2. Check which package manager is detected:
```bash
# The module will log which package manager it detects
dart run ../../bin/main.dart apply -c config
```

### Test Version Constraints

1. Modify package versions in the config:
```configr
package_versions {
  vim "2.0.0"  # Downgrade to test version constraints
  git "2.30.0"
}
```

2. Run the configuration and observe version handling.

### Test Repository Management

1. Add custom repositories:
```configr
repositories ["ppa:example/ppa", "https://example.com/repo"]
```

2. Run the configuration and observe repository addition.

### Test Error Handling

1. Try installing non-existent packages:
```configr
packages ["nonexistent-package-12345"]
```

2. Run the configuration and observe error handling.

## Expected Results

After running the package configuration, you should see:

- Packages installed, upgraded, or removed based on the configuration
- Statistics showing packages processed, skipped, and errors encountered
- Detailed logs of package operations
- Proper handling of different package managers
- Version constraints applied correctly
- Repository management working as expected

## Monitoring and Logs

Check the `app.log` file for detailed information about:
- Package manager detection
- Package operations performed
- Packages processed, skipped, and errors encountered
- Repository management operations
- Privilege escalation activities
- Any errors or warnings

## Platform-Specific Notes

### Linux (APT - Debian/Ubuntu)
- Requires sudo privileges
- May prompt for password during privilege escalation
- Package cache updates may take time
- Repository management requires proper GPG keys

### Linux (Pacman - Arch)
- Requires sudo privileges
- AUR packages may require additional setup
- Package cache updates are typically fast

### Linux (Pamac - Manjaro)
- Requires sudo privileges
- Integrates with AUR automatically
- GUI notifications may appear

### macOS (Homebrew)
- Requires administrator privileges
- May prompt for password
- Formula updates may take time
- Cask packages may require additional permissions

### Windows (Chocolatey)
- Requires administrator privileges
- PowerShell execution policy may need adjustment
- Package downloads may take time

### Windows (Winget)
- Requires administrator privileges
- Microsoft Store integration
- Package verification may take time

## Cleanup

To clean up packages installed by this example:

```bash
# Remove packages (be careful with system packages)
dart run ../../bin/main.dart apply -c config --override operation=uninstall
```

Or manually remove packages using your system's package manager:

```bash
# APT
sudo apt remove git curl wget vim nano htop tree

# Pacman
sudo pacman -R git curl wget vim nano htop tree

# Homebrew
brew uninstall git curl wget vim nano htop tree
```

## Customization

You can modify the configuration to:
- Change package lists for your specific needs
- Adjust version constraints
- Add or remove repositories
- Change package managers
- Modify operation types (install, uninstall, upgrade, reinstall)
- Adjust cache and skipping behavior

## Safety Considerations

1. **Backup**: Create system backups before running package operations
2. **Testing**: Test configurations in isolated environments first
3. **Permissions**: Ensure you have appropriate system privileges
4. **Dependencies**: Be aware of package dependencies and conflicts
5. **Rollback**: Have a plan for rolling back changes if needed

This example provides a comprehensive demonstration of the package module's capabilities for various package management scenarios across different platforms.

