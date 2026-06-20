# NPM Global Installation Example

This example demonstrates installing npm packages globally using the `install_globally true` configuration.

## Prerequisites

- Node.js installed on your system
- npm package manager (comes with Node.js)
- No sudo privileges required (npm installs to user directory by default)

## Running the Example

```bash
# Run the global npm package configuration
dart run ../../../../bin/main.dart apply -c config
```

## What This Example Demonstrates

### 1. Global Development Tools (`global-dev-tools`)
- Installs essential Node.js development tools globally: typescript, eslint, prettier, nodemon, ts-node
- Specifies exact versions for key packages
- Lists installed global packages after installation

### 2. Global Web Development Tools (`global-web-tools`)
- Installs web development tools globally: webpack, webpack-cli, vite, rollup, parcel
- Specifies versions for webpack and vite
- Demonstrates modern web development toolchain

### 3. Global Testing Frameworks (`global-testing-tools`)
- Installs testing tools globally: jest, mocha, chai, cypress, playwright
- Specifies versions for jest and mocha
- Covers both unit and integration testing

### 4. Global CLI Tools (`global-cli-tools`)
- Installs CLI utilities globally: pm2, forever, concurrently, cross-env
- Demonstrates process management and development tools

## Global Installation Features

### Configuration
```configr
package {
  packages ["typescript", "eslint", "prettier"]
  operation "install"
  package_manager "npm"
  install_globally true  # Install globally using npm install -g
  update_cache false
  skip_if_installed true
}
```

### Version Constraints
```configr
package_versions {
  typescript "5.0.0"
  eslint "8.0.0"
  prettier "3.0.0"
}
```

## Expected Results

After running the global configuration:
- Packages installed globally via `npm install -g`
- Packages available system-wide from any directory
- Version constraints applied correctly
- Global package operations completed successfully

## Cleanup

To remove globally installed packages:

```bash
# Remove global packages
npm uninstall -g typescript eslint prettier nodemon ts-node
npm uninstall -g webpack webpack-cli vite rollup parcel
npm uninstall -g jest mocha chai cypress playwright
npm uninstall -g pm2 forever concurrently cross-env
```

## Global Installation Notes

- Global packages are installed in npm's global directory
- Use `npm list -g` to list global packages
- Use `npm outdated -g` to check for outdated global packages
- Global packages are available from any directory
- Consider using `--save` or `--save-dev` for project dependencies instead
