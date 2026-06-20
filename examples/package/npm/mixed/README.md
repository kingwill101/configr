# NPM Mixed Installation Example

This example demonstrates using both global and local npm package installations in a single configuration.

## Prerequisites

- Node.js installed on your system
- npm package manager (comes with Node.js)
- No sudo privileges required

## Running the Example

```bash
# Run the mixed npm package configuration
dart run ../../../../bin/main.dart apply -c config
```

## What This Example Demonstrates

### 1. Global CLI Tools (`global-cli-tools`)
- Installs development tools globally: typescript, eslint, prettier, nodemon
- Specifies exact versions for key packages
- Lists installed global packages after installation
- These tools are available system-wide

### 2. Local Project Dependencies (`local-project-deps`)
- Creates a package.json file for the project
- Installs runtime dependencies locally: express, cors, helmet, morgan, dotenv
- Specifies exact versions for key packages
- Lists installed local packages after installation
- These packages are only available in the current project

### 3. Local Development Dependencies (`local-dev-deps`)
- Installs testing tools locally: jest, mocha, chai, supertest
- Specifies versions for jest and mocha
- These are project-specific testing tools

### 4. Global Web Development Tools (`global-web-tools`)
- Installs web development tools globally: webpack, vite, rollup
- Specifies versions for webpack and vite
- These tools are available system-wide for any project

## Mixed Installation Strategy

### When to Use Global Installation
- **CLI Tools**: Tools you want to use from any directory (typescript, eslint, prettier)
- **Build Tools**: Tools used across multiple projects (webpack, vite, rollup)
- **Development Utilities**: Tools for general development (nodemon, pm2)

### When to Use Local Installation
- **Runtime Dependencies**: Packages your application needs to run (express, cors, helmet)
- **Project-Specific Tools**: Tools specific to this project (jest, mocha, chai)
- **Version-Specific Dependencies**: Packages that need specific versions for this project

## Configuration Examples

### Global Installation
```configr
package {
  packages ["typescript", "eslint", "prettier"]
  operation "install"
  package_manager "npm"
  install_globally true  # Available system-wide
  update_cache false
  skip_if_installed true
}
```

### Local Installation
```configr
package {
  packages ["express", "cors", "helmet"]
  operation "install"
  package_manager "npm"
  install_globally false  # Available only in current project
  update_cache false
  skip_if_installed true
}
```

## Expected Results

After running the mixed configuration:
- Global packages installed via `npm install -g` (available system-wide)
- Local packages installed via `npm install` (available only in project)
- node_modules directory created with local dependencies
- package-lock.json created for local package version locking
- Both global and local package operations completed successfully

## Cleanup

To remove packages installed by this example:

```bash
# Remove global packages
npm uninstall -g typescript eslint prettier nodemon
npm uninstall -g webpack vite rollup

# Remove local packages
rm -rf node_modules package-lock.json
# Or remove specific local packages:
npm uninstall express cors helmet morgan dotenv
npm uninstall jest mocha chai supertest
```

## Best Practices

1. **Use Global for CLI Tools**: Install development tools globally for system-wide access
2. **Use Local for Dependencies**: Install runtime and project-specific packages locally
3. **Version Control**: Keep package.json and package-lock.json in version control
4. **Environment Consistency**: Use package-lock.json to ensure consistent installs
5. **Separation of Concerns**: Keep global tools separate from project dependencies
