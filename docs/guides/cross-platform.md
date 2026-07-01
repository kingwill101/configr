# Cross-Platform Execution Strategy

Configr v2 provides comprehensive cross-platform support through platform-specific strategies, enabling seamless execution on Linux, macOS, FreeBSD, and Windows targets.

## Overview

Configr uses execution strategies to adapt commands, hooks, and network operations to the target platform. This ensures consistent behavior across operating systems while respecting platform conventions and limitations.

## Shell Types

Configr supports multiple shell types and automatically selects the appropriate one for each platform:

- **sh** — POSIX `sh` commands (Linux, macOS, FreeBSD)
- **bash** — Bash commands (available on most Unix-like systems)
- **powershell** — PowerShell commands (Windows)
- **cmd** — Windows Command Prompt (legacy fallback)

For most use cases, you do not need to specify a shell explicitly. Configr detects the target platform and selects the best available option automatically.

## Capabilities

Configr checks target capabilities to determine which execution methods are available:

- **exec.sh** — Target can run POSIX `sh` commands
- **exec.bash** — Target has Bash available
- **exec.powershell** — Target has PowerShell or `pwsh` available
- **exec.process** — Target provides a process execution backend

Capability detection happens at runtime and informs which commands and strategies can be used.

## Script Execution

Configr uses platform-specific strategies for executing scripts and inline commands:

### Unix Execution (Linux, macOS, FreeBSD)

- Uses `sh` or `bash` depending on availability
- Commands execute directly through the platform shell
- POSIX-compliant script execution with proper quoting

### Windows Execution

- Uses PowerShell by default
- Commands are encoded to handle PowerShell quoting rules safely
- Supports PowerShell Core (`pwsh`) when available

## Hook Execution

Pre-apply and post-apply scripts use platform-aware hook execution:

- **Linux/macOS/FreeBSD**: Bash scripts executed via `bash`
- **Windows**: PowerShell scripts executed via `powershell.exe`

Hook scripts are transferred to the target when needed and cleaned up after execution.

## Network Operations

Network operations adapt to the target platform:

### Linux, macOS, FreeBSD

- HTTP requests use `curl`
- DNS resolution uses `getent`, `nslookup`, `host`, or `dig`
- TCP probes use `nc` or equivalent
- Ping uses `ping`

### Windows

- HTTP requests use PowerShell `Invoke-WebRequest`
- DNS resolution uses PowerShell `Resolve-DnsName`
- TCP probes use PowerShell `Test-NetConnection`
- Ping uses PowerShell `Test-Connection`

## Block-Level Cross-Platform Support

Multiple Configr blocks adapt their behavior based on the target platform.

### Execute Block

The `execute` block supports configurable shell selection:

- On Unix-like systems, `sh` is the default
- On Windows, PowerShell is the default
- The `shell` property can override the platform default
- Environment variables, working directory, timeouts, and input are handled consistently across platforms

### Raw Block

The `raw` block selects the appropriate executable automatically:

- On Unix-like systems, `sh` is used by default
- On Windows, PowerShell is used automatically
- The `executable` property can override the platform default

### Script Block

The `script` block runs scripts directly without wrapping them in an outer shell:

- On Unix-like systems, scripts run through `sh` or `bash`
- On Windows, scripts run through PowerShell
- Execution errors are reported with platform-appropriate detail

### Symlink Block

The `symlink` block uses native symlink creation when available:

- On Unix-like systems, native `ln` semantics are used
- On Windows, PowerShell `New-Item -ItemType SymbolicLink` is used

### Cron, User, Systemd Blocks

These system-management blocks use platform strategies to select the correct system commands. Platform support varies by block and operating system.

## Path Handling

Configr normalizes paths across platforms:

- Unix paths use forward slashes
- Windows paths use backslashes or forward slashes (PowerShell accepts both)
- Path variables like `$env:USERPROFILE` on Windows or `$HOME` on Unix are resolved at runtime

## Error Handling and Output

- Stdout and stderr are captured separately on all platforms
- Exit codes are checked on Unix and Windows
- Platform-specific exit handling ensures consistent failure detection
- Long-running command output can be streamed line by line

## Audit Logging

The Execution Service writes structured audit records for every command:

- Command, arguments, and working directory
- Start time, duration, and exit code
- Stdout and stderr (redacted when appropriate)
- PowerShell encoded commands are decoded for readable logs

This applies regardless of platform.

## Best Practices

1. **Do not specify shell unless necessary** — let Configr select the best default for the platform
2. **Use platform-appropriate commands** — Unix commands on Unix targets, PowerShell cmdlets on Windows
3. **Test on the target platform** — verify that scripts and commands work on the actual operating system
4. **Use relative paths when possible** — Configr handles path normalization
5. **Check capabilities at runtime** — use `exec.*` capabilities to adapt to target features

## Limitations

- Windows PowerShell requires PowerShell 5.1+ or PowerShell 7+
- Some Unix-specific commands are not available on Windows
- System management blocks (cron, systemd, user/group) may have limited or no support on certain platforms
- Package management is platform-specific (apt, dnf, brew, winget, etc.)

For block-by-block platform support details, see the individual block documentation.
