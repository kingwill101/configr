# Commands and Subcommands Blocks

The top-level `commands` block defines named command models. Resource-level
`subcommands` define commands attached to a specific resource entry.

```i3
commands {
  command "build" {
    command = "make"
    parameters "test"
  }
}
```

Run a top-level command by name with the CLI:

```bash
configr run build
```

Extra arguments after the name are appended to the configured `parameters`:

```bash
configr run build -- --coverage
```

## Top-Level Commands

| Block | Scope | Description |
|-------|-------|-------------|
| `commands` | top-level | Container for command entries |
| `command "<name>"` | inside `commands` | Defines one named command |

Command properties:

| Property | Description |
|----------|-------------|
| `command` | Executable or command string |
| `parameters` | List of parameters |
| `id` | Optional identifier |
| `status` | Stored status metadata |
| `timestamp` | Stored timestamp metadata |
| `sha256` | Stored checksum metadata |

## CLI Usage

```i3 title="config"
commands {
  command "test" {
    command = "make"
    parameters "test"
  }

  command "build-docs" {
    command = "npm"
    parameters "run" "docs:build"
  }
}
```

```bash
configr run test
configr run build-docs
```

Use `--working-directory` when the command should run from a specific
directory:

```bash
configr run test --working-directory /path/to/project
```

Use `--shell` only when the executable itself needs to be launched through the
platform shell. Prefer explicit commands and parameters over shell redirection
or compound shell expressions; command arguments are sanitized before execution.

```i3
commands {
  command "cleanup" {
    command = "rm"
    parameters "-rf" "build/tmp"
  }

  command "shell-example" {
    command = "echo"
    parameters "hello from shell"
  }
}
```

```bash
configr run shell-example --shell
```

When global SSH flags are provided, `configr run` executes through the same SSH
execution backend used by remote apply:

```bash
configr run test --host vm1 --ssh-user root --ssh-key ~/.ssh/id_ed25519
```

## Resource Subcommands

```i3
resources {
  resource {
    id = "app"
    type = "directory"
    destination = "/opt/app"

    subcommands {
      restart {
        command = "systemctl"
        parameters "restart" "app"
      }
    }
  }
}
```

`subcommands` accepts dynamic entry names such as `restart`, `install`, or
`verify`. Each entry supports the same command metadata as top-level
`command` entries.

Resource subcommands are stored on the resource model. The current CLI `run`
command targets top-level `commands {}` entries.
