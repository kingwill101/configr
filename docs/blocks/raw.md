# Raw Block

Executes a raw command on the target via the shell — runs commands directly without a module infrastructure.

## Platform Support

- **Linux/macOS/FreeBSD**: Uses native `sh`
- **Windows**: Uses PowerShell automatically

## Cross-Platform Execution

Configr selects the correct shell automatically:

- On Linux, macOS, and FreeBSD, commands run through `sh` by default
- On Windows, commands run through PowerShell by default
- Some environments support `bash` as an alternative on Unix-like systems

PowerShell commands are encoded to avoid quoting issues. All commands run through Configr's Execution Service, which handles platform-specific process invocation and output capture.

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `command` | `string` | `""` | The command to execute |
| `args` | `string` | `""` | Additional arguments appended to the command |
| `chdir` | `string` | `""` | Working directory to change into before execution |
| `stdin` | `string` | `""` | Standard input to pass to the command |
| `executable` | `string` | `"/bin/sh"` | Shell to use for command execution (auto-detected on Windows) |

## Examples

### Run a Simple Command

```
raw {
  command = "uptime"
}
```

### Command with Arguments

```
raw {
  command = "df"
  args = "-h"
}
```

### Run in a Specific Directory

```
raw {
  command = "make"
  chdir = "/opt/build"
}
```

### Override Platform Detection

```
raw {
  command = "echo 'Hello'"
  executable = "/bin/bash"
}
```

## Rollback

No rollback is performed. The command's effects are not tracked or undone.
