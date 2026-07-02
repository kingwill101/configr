# Script Block

Copies a local script to the target system, makes it executable, and runs it.

## Platform Support

- **Linux/macOS/FreeBSD**: Copies and executes via native shell execution
- **Windows**: Uses PowerShell for script execution via `HookStrategy`

## Cross-Platform Execution

The Script block now supports cross-platform execution through the `HookStrategy` pattern:

### Unix Execution (Linux/macOS/FreeBSD)

- Uses `bash` for script execution
- Temporarily file is created with executable permissions
- Script runs directly without shell wrapper
- Proper error detection and cleanup

### Windows Execution

- Uses PowerShell `powershell.exe` for script execution
- Scripts are executed via encoded commands to avoid quoting issues
- Proper error detection and cleanup

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `script` | `string` | `""` | Path to the local script file to transfer and execute |
| `args` | `string` | `""` | Command-line arguments to pass to the script |
| `chdir` | `string` | `""` | Working directory to run the script in |
| `creates` | `string` | `""` | Skip execution if this path already exists |
| `removes` | `string` | `""` | Skip execution if this path does not exist |

## Examples

### Run a Setup Script

```
script {
  script = "./scripts/setup.sh"
}
```

On Windows, this would execute:
```powershell
powershell.exe -NoProfile -EncodedCommand <base64-encoded-invoke-script>
```

### Run with Arguments

```
script {
  script = "./deploy.sh"
  args = "--env production --tag v1.2.3"
}
```

### Run Only If Target Does Not Exist

```
script {
  script = "./init-db.sh"
  creates = "/var/lib/db/initialized"
}
```

### Run Only If Source Exists

```
script {
  script = "./migrate.sh"
  removes = "/tmp/migration-lock"
}
```

### PowerShell Script on Windows

```
script {
  script = "./setup.ps1"
  args = "-Environment Production"
}

# On Windows, this runs via PowerShell directly:
# & 'C:\path\to\setup.ps1' -Environment Production
```

### Cross-Platform Script

```
script {
  script = "./setup.sh"
  # Works on Linux/macOS via bash
  # Use a .ps1 file for Windows-specific scripting
}
```

## Platform-Specific Notes

### Linux/macOS

- Scripts are copied to target and made executable with `chmod +x`
- Executed directly without shell wrapper
- Platform-specific shebang lines respected
- Full POSIX script support

### FreeBSD

- Same as Linux/macOS
- POSIX-compliant script execution
- No additional dependencies required

### Windows

- Scripts executed via PowerShell strategy
- Uses `-EncodedCommand` to avoid quoting issues
- PowerShell execution policy must allow script execution (typically `RemoteSigned`)
- Administrator privileges may be required for certain operations

## Rollback

No rollback is performed. The temporary script file is deleted after execution regardless of success.

## Error Handling

The Script block now provides detailed error reporting:

- **Exit code checking**: Non-zero exit codes are reported with stderr
- **Platform-specific error messages**: PowerShell vs Unix error formatting
- **Cleanup on failure**: Temporary files are deleted even on execution failure
- **Directory cleanup**: Created directories are cleaned up on rollback if needed

## Security Considerations

1. **Script Execution**: Scripts are executed with the privileges of the target user
2. **Temporary Files**: Scripts are written to temporary locations with secure permissions
3. **Cleanup**: Temporary scripts are deleted after execution
4. **Execution Policy**: Windows requires appropriate PowerShell execution policy

## Best Practices

1. **Use platform-specific scripts**: `.sh` for Unix, `.ps1` for Windows
2. **Test on target platform**: Verify scripts work on actual target OS
3. **Error handling**: Include error checking in scripts
4. **Idempotent scripts**: Design scripts to be safely re-runnable
5. **Argument passing**: Use `args` for cross-platform argument passing
6. **Working directory**: Use `chdir` to set expected working directory
