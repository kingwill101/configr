# NPM Package Manager Examples

This directory contains examples demonstrating Node.js package management using the npm package manager with different installation strategies.

## Directory Structure

- **`global/`** - Global package installation examples
- **`local/`** - Local package installation examples  
- **`mixed/`** - Mixed global and local installation examples
- **`examples/`** - Additional test configurations and shared files

## Prerequisites

- Node.js installed on your system
- npm package manager (comes with Node.js)
- No sudo privileges required (npm installs to user directory by default)

## Running Examples

```bash
# Global installation example
cd global && dart run ../../../../bin/main.dart apply -c config

# Local installation example
cd local && dart run ../../../../bin/main.dart apply -c config

# Mixed installation example
cd mixed && dart run ../../../../bin/main.dart apply -c config

# Test configurations
cd examples && dart run ../../../../bin/main.dart apply -c upgrade-test.config
```

## What This Example Demonstrates

### 1. Node.js Development Tools (`node-dev-tools`)
- Installs essential Node.js development tools: typescript, eslint, prettier, nodemon, ts-node
- Specifies exact versions for key packages
- Uses npm package manager specifically
- Lists installed global packages after installation

### 2. Web Development Tools (`web-dev-tools`)
- Installs web development tools: webpack, webpack-cli, vite, rollup, parcel
- Specifies versions for webpack and vite
- Demonstrates modern web development toolchain

### 3. Testing Frameworks (`testing-tools`)
- Installs testing tools: jest, mocha, chai, cypress, playwright
- Specifies versions for jest and mocha
- Covers both unit and integration testing

### 4. CLI Tools and Utilities (`cli-tools`)
- Installs CLI utilities: nodemon, pm2, forever, concurrently, cross-env
- Demonstrates process management and development tools

### 5. Package Upgrades (`upgrade-packages`)
- Upgrades typescript, eslint, and prettier to newer versions
- Uses npm package manager specifically
- Only upgrades if packages are already installed

### 6. Package Removal (`remove-packages`)
- Removes unused packages: old-package, unused-tool, deprecated-app
- Uses npm package manager specifically
- Skips packages that are not installed

### 7. Package Reinstallation (`reinstall-packages`)
- Reinstalls potentially corrupted packages
- Uses force option to ensure reinstallation
- Demonstrates package repair operations

### 8. Project-Specific Packages (`project-packages`)
- Creates a package.json file for testing
- Installs project dependencies: express, cors, helmet, morgan, dotenv
- Demonstrates local package installation
- Lists installed packages after installation

## Installation Strategies

### Global Installation (`global/`)
- Packages installed system-wide using `npm install -g`
- Available from any directory
- Best for CLI tools and development utilities
- Example: typescript, eslint, prettier, nodemon

### Local Installation (`local/`)
- Packages installed in project directory using `npm install`
- Available only in current project
- Best for runtime dependencies and project-specific tools
- Example: express, cors, helmet, jest, mocha

### Mixed Installation (`mixed/`)
- Combines both global and local installations
- Global tools for system-wide access
- Local packages for project-specific needs
- Best practice for most development workflows

## NPM-Specific Features

### Configuration Options
```configr
# Global installation
package_manager "npm"
install_globally true
update_cache false  # npm doesn't need cache updates

# Local installation
package_manager "npm"
install_globally false
update_cache false
```

### Version Constraints
```configr
package_versions {
  typescript "5.0.0"
  eslint "8.0.0"
  prettier "3.0.0"
}
```

### Project Dependencies
- Local packages are installed in `node_modules/`
- Global packages are installed in npm's global directory
- package.json manages project dependencies

### Configuration Options
- `install_globally true` (default): Install packages globally using `npm install -g`
- `install_globally false`: Install packages locally using `npm install`
- Global packages are available system-wide
- Local packages are only available in the current project directory

## Testing Different Scenarios

### Test Global Package Installation
1. Run the configuration and observe global package installation
2. Check installed packages with `npm list -g --depth=0`

### Test Version Constraints
1. Modify package versions in the config
2. Run and observe version handling

### Test Project Dependencies
1. Use the project-packages resource
2. Observe local package installation

### Test Package Operations
1. Test install, upgrade, uninstall, and reinstall operations
2. Observe different package management scenarios

## Expected Results

After running the npm configuration:
- Global packages installed via npm
- Project dependencies installed locally
- Version constraints applied correctly
- Package operations completed successfully

## Cleanup

To remove packages installed by this example:

```bash
# Remove global packages
npm uninstall -g typescript eslint prettier nodemon ts-node
npm uninstall -g webpack webpack-cli vite rollup parcel
npm uninstall -g jest mocha chai cypress playwright
npm uninstall -g pm2 forever concurrently cross-env

# Remove local packages (if project-packages was run)
npm uninstall express cors helmet morgan dotenv
```

## NPM-Specific Notes

- No sudo privileges required
- Global packages installed in npm's global directory
- Local packages installed in project's node_modules/
- Use `npm list -g` to list global packages
- Use `npm list` to list local packages
- Use `npm outdated` to check for outdated packages
- Use `npm audit` to check for security vulnerabilities
- Consider using `--save` or `--save-dev` for project dependencies

