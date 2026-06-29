# Splitting Configs with Include

Use the top-level `include` command to split a config across multiple files.
Included files are parsed as if their contents appeared at the include site.

```i3 title="config"
plugin {
  lua = "plugins/journal.lua"
}

include inventory.conf
include packages.conf
include dotfiles.conf
```

```i3 title="inventory.conf"
inventory {
  default_targets = ["vm1"]

  host "vm1" {
    address = "127.0.0.1"
    username = "root"
    privateKey = "$sshPrivateKey"
    roles = ["web"]
  }
}
```

```i3 title="packages.conf"
package {
  name = "curl"
  state = "present"
}

package {
  name = "git"
  state = "present"
}
```

```i3 title="dotfiles.conf"
resource {
  id = "shell-config"
  destination = "$home/.zshrc"

  actions {
    copy {
      source = "dotfiles/zshrc"
      destination = "$home/.zshrc"
    }
  }
}
```

## Path Resolution

Relative include paths are resolved from the directory containing the main
config file.

```text
my-config/
  config
  inventory.conf
  packages.conf
  roles/
    web.conf
```

```i3 title="config"
include inventory.conf
include packages.conf
include roles/web.conf
```

This works the same regardless of the process working directory used to launch
Configr.

## Ordering

Includes are processed in order. Put setup blocks before files that depend on
them:

```i3 title="config"
# Plugins must be loaded before included files use plugin-provided blocks.
plugin {
  lua = "plugins/journal.lua"
}

# Inventory should appear before multi-host declarations that use it.
include inventory.conf

# Regular actions can be split by concern.
include packages.conf
include services.conf
include dotfiles.conf
```

Variables and secrets declared before an include are available to the included
file. Variables declared inside an included file are available to later blocks
according to the normal processor context rules.

## Organizing by Concern

A practical layout is:

```text
.configr/
  cache/
  backups/
config
inventory.conf
secrets.conf
packages.conf
services.conf
dotfiles.conf
plugins/
  journal.lua
dotfiles/
  zshrc
  gitconfig
```

```i3 title="config"
include secrets.conf
include inventory.conf
include packages.conf
include services.conf
include dotfiles.conf
```

Use `resource` blocks inside included files when you want grouped operations,
and use top-level action blocks for direct single-step operations.
