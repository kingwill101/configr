# Raw Block

Executes a raw command on the target via the shell — runs commands directly without a module infrastructure.

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `command` | `string` | `""` | The command to execute |
| `args` | `string` | `""` | Additional arguments appended to the command |
| `chdir` | `string` | `""` | Working directory to change into before execution |
| `stdin` | `string` | `""` | Standard input to pass to the command |
| `executable` | `string` | `"/bin/sh"` | Shell to use for command execution |

The command is executed as: `executable -c "cd chdir && command args"`.

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

### Use a Different Shell

```
raw {
  command = "echo 'Hello'"
  executable = "/bin/bash"
}
```

## Platform Support

| Platform | Implementation |
|----------|---------------|
| Linux    | Full — shell-based |
| macOS    | Full — shell-based |
| FreeBSD  | Full — shell-based |

## Rollback

No rollback is performed. The command's effects are not tracked or undone.
