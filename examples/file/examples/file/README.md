# Configr File Module Demo

This example demonstrates the capabilities of the Configr File Module.

## Features Demonstrated

- File creation with custom content
- Directory creation
- File editing with different modes
- Backup functionality
- Rollback support

## Files Created

- `app.conf`: Application configuration file
- `setup.sh`: Shell script for setup
- `config.json`: JSON configuration file
- `README.md`: This documentation file

## Usage

Run this example with:

```bash
dart run ../../bin/main.dart apply
```

To rollback all changes:

```bash
dart run ../../bin/main.dart rollback
```