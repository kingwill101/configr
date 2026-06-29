# Resources, Resource, Actions, File, and Directory Blocks

The `resource` block is a supported grouping primitive for actions that belong
to the same managed object. Use it when a set of actions should share context,
inherit resource-level properties, render an in-memory template, or report as a
single resource in events and rollback output.

`resource { ... }` works as a top-level block. The `resources { ... }` block is
an optional container when you want to group several resource entries together.

```i3
resource {
  id = "shell-config"
  type = "file"
  source = "./zshrc"
  destination = "$home/.zshrc"

  actions {
    copy {
      source = "./zshrc"
      destination = "$home/.zshrc"
    }
  }
}
```

## Resource Entries

Inside `resources`, use either a generic `resource` block or an inline resource
type:

```i3
resources {
  file {
    id = "motd"
    destination = "/etc/motd"

    actions {
      file {
        path = "/etc/motd"
        content = "Managed by Configr"
      }
    }
  }

  directory {
    id = "app-dir"
    destination = "/opt/myapp"
  }
}
```

## Resource Properties

| Property | Description |
|----------|-------------|
| `id` | Resource identifier |
| `type` | Resource type when using `resource {}` |
| `source` | Source path or value |
| `destination` | Destination path |
| `status` | Stored status metadata |
| `sha256` | Stored checksum metadata |

## Nested Blocks

| Block | Scope | Description |
|-------|-------|-------------|
| `actions` | inside `resource`, `file`, `directory` | Contains action blocks |
| `template` | inside resource entries | Defines a template model for the resource |
| `vars` | inside `template` | Supplies template variables |
| `subcommands` | inside resource entries | Defines named subcommands for the resource |

Top-level action blocks and resource-scoped action blocks are both valid.
Use top-level actions for simple one-off operations. Use `resource` when actions
should be treated as one managed resource.
