# Windows Support

Configr can target Windows machines over SSH. This guide covers the current state of Windows support and what to expect when running Configr against Windows targets.

## Current State

Windows support is provided through the same cross-platform execution layer used for Linux, macOS, and FreeBSD targets. When Configr connects to a Windows machine over SSH, it automatically detects the platform and selects PowerShell as the default shell.

### What Works Today

Blocks that rely on Configr's cross-platform execution strategies work on Windows targets today:

- **execute** — Runs commands through PowerShell with automatic PowerShell-style quoting
- **raw** — Executes raw commands on the target using the platform-appropriate shell
- **script** — Transfers and runs scripts using the target's supported execution strategy
- **file** — Creates and edits files on the target
- **copy / move / rename / delete** — File and directory operations
- **touch** — Updates file timestamps via PowerShell
- **backup / compress / decompress** — File operations with standard tooling
- **template / lineinfile / blockinfile / replace** — File content management
- **slurp / stat / fetch / download** — File inspection and transfer
- **symlink** — Creates symbolic links using PowerShell on Windows
- **echo / debug / fail / assert / set_fact / pause** — Control and reporting
- **gather_facts** — Collects limited system facts on Windows
- **wait_for / network / uri** — Network connectivity and HTTP operations using PowerShell equivalents

### Planned Windows Blocks

Configr will eventually include dedicated Windows blocks for native Windows system management:

- **service** — Windows service management via PowerShell
- **task** — Windows Task Scheduler management
- **user** — Local user and group management
- **package** — Windows package management
- **firewall** — Windows Firewall configuration
- **hostname** — System hostname management
- **timezone / locale_gen / sysctl / mount** — Platform-specific system configuration

These are not yet implemented and will be added in a future release.

## Targeting Windows from Configr

### SSH Connection

Windows targets are managed through SSH. You can connect using CLI flags or an inline connection block.

```bash
configr apply --host 192.168.1.100 --ssh-user Administrator --ssh-password password
```

```i3
connection {
  host = "192.168.1.100"
  username = "Administrator"
  password = "password"
}

execute {
  command = "hostname"
}
```

### Prerequisites

The Windows target needs:

- An SSH server (OpenSSH Server or equivalent)
- PowerShell 5.1 or later
- Appropriate execution policy for running PowerShell commands

## Shell Behavior on Windows

Configr automatically selects PowerShell as the default shell on Windows targets. This affects how commands are quoted and executed.

- PowerShell is used for all shell operations
- Commands are encoded when necessary to handle PowerShell quoting rules
- Unix-style shell commands will not work unless PowerShell equivalents exist

## File Paths

Windows paths can use either backslashes or forward slashes:

```i3
file {
  file_path = "C:/temp/configr_test/hello.txt"
  content = "Hello from Configr"
}

symlink {
  source = "C:/temp/configr_test/hello.txt"
  destination = "C:/temp/configr_test/hello_link.txt"
}
```

## Hooks

Pre-apply and post-apply scripts use the target platform's execution strategy. On Windows, hooks run through PowerShell.

## Network Operations

Network-related blocks adapt to Windows by using PowerShell cmdlets for HTTP requests, DNS resolution, TCP probes, and ping operations instead of Unix utilities like `curl`, `nc`, and `nslookup`.

## Limitations

- Some Unix-only commands are not available on Windows targets
- Blocks that rely on Linux-specific system tools (e.g., `systemd`, `firewalld`, `ufw`, `cron`) do not run on Windows today
- Windows-specific management blocks are planned but not yet implemented
- PowerShell execution policy must allow the commands Configr needs to run

## Future Work

Configr's Windows support is actively being expanded. Upcoming work includes:

- Dedicated Windows service management blocks
- Windows Task Scheduler support
- Windows package management (winget, chocolatey)
- Windows Firewall and security configuration
- Local user and group management blocks
