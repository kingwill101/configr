# NPM Local Installation Example

This example demonstrates installing npm packages locally using the `install_globally false` configuration.

## Prerequisites

- Node.js installed on your system
- npm package manager (comes with Node.js)
- No sudo privileges required

## Running the Example

```bash
# Run the local npm package configuration
dart run ../../../../bin/main.dart apply -c config
```

## What This Example Demonstrates

### 1. Local Dependencies (`local-dependencies`)
- Creates a package.json file for the project
- Installs runtime dependencies locally: express, cors, helmet, morgan, dotenv
- Specifies exact versions for key packages
- Lists installed local packages after installation

### 2. Local Development Dependencies (`local-dev-dependencies`)
- Installs development tools locally: typescript, eslint, prettier, nodemon, ts-node
- Specifies versions for typescript and eslint
- Demonstrates local development toolchain

### 3. Local Testing Dependencies (`local-test-dependencies`)
- Installs testing tools locally: jest, mocha, chai, supertest
- Specifies versions for jest and mocha
- Covers unit and integration testing

## Local Installation Features

### Configuration
```configr
package {
  packages ["express", "cors", "helmet"]
  operation "install"
  package_manager "npm"
  install_globally false  # Install locally using npm install
  update_cache false
  skip_if_installed true
}
```

### Project Structure
```
project/
├── package.json          # Project configuration
├── node_modules/         # Local packages (created by npm)
│   ├── express/
│   ├── cors/
│   └── ...
└── package-lock.json     # Lock file (created by npm)
```

## Expected Results

After running the local configuration:
- Packages installed locally via `npm install`
- Packages available only in the current project directory
- node_modules directory created with dependencies
- package-lock.json created for version locking
- Local package operations completed successfully

## Cleanup

To remove locally installed packages:

```bash
# Remove local packages (removes node_modules and package-lock.json)
rm -rf node_modules package-lock.json

# Or remove specific packages
npm uninstall express cors helmet morgan dotenv
npm uninstall typescript eslint prettier nodemon ts-node
npm uninstall jest mocha chai supertest
```

## Local Installation Notes

- Local packages are installed in `node_modules/` directory
- Use `npm list` to list local packages
- Use `npm outdated` to check for outdated local packages
- Local packages are only available in the current project directory
- package.json manages project dependencies and scripts
- package-lock.json ensures consistent installs across environments
