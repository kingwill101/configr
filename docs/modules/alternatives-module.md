# Alternatives Module

Manages command alternatives (`update-alternatives`) — Ansible-style.

## Overview

The Alternatives Module manages symbolic link alternatives for commands, following the Debian `update-alternatives` system and the Ansible `community.general.alternatives` module pattern.

## Features

- **Multi-state management**: `present`, `selected`, `auto`, `absent` states
- **Master/slave links**: Register subcommands (slaves) alongside the main alternative
- **Priority system**: Set priority for auto mode selection
- **Automatic mode**: Let the system choose the highest-priority alternative
- **Debian/Ubuntu support**: Full `update-alternatives` integration
- **RedHat placeholder**: Structure prepared for RHEL `alternatives` command

## Properties

### Standard Properties
- `name` (required): Alternative name (e.g., `editor`, `java`, `python`)
- `state` (required): One of `selected`, `present`, `auto`, `absent`

### Alternatives Properties
- `path`: Path to the alternative executable (required for `selected`, `present`, `absent`)
- `link`: Path to the master symlink (required for `present` on Debian)
- `priority`: Priority number for auto mode (default: `50`)
- `subcommands`: List of slave alternatives, each with `link`, `name`, `path`

### State Details

| State | Behavior |
|-------|----------|
| `selected` | Install if needed and set as the selected alternative |
| `present` | Install the alternative without changing the selected one |
| `auto` | Install if needed and set to automatic mode |
| `absent` | Remove the alternative |

## Examples

### Register and Select Java

```configr
resource {
  type "alternatives"
  name "java"
  state "selected"

  actions {
    alternatives {
      path "/usr/lib/jvm/java-11-openjdk/bin/java"
      link "/usr/bin/java"
      priority "1101"
    }
  }
}
```

### Register with Slave Alternatives

```configr
resource {
  type "alternatives"
  name "java"
  state "present"

  actions {
    alternatives {
      path "/usr/lib/jvm/java-17-openjdk/bin/java"
      link "/usr/bin/java"
      priority "1701"
      subcommands [
        { link: "/usr/bin/javac", name: "javac", path: "/usr/lib/jvm/java-17-openjdk/bin/javac" },
        { link: "/usr/bin/javadoc", name: "javadoc", path: "/usr/lib/jvm/java-17-openjdk/bin/javadoc" },
      ]
    }
  }
}
```

### Set to Auto Mode

```configr
resource {
  type "alternatives"
  name "editor"
  state "auto"

  actions {
    alternatives {
      path "/usr/bin/vim.basic"
      link "/usr/bin/editor"
      priority "50"
    }
  }
}
```

### Remove an Alternative

```configr
resource {
  type "alternatives"
  name "old-java"
  state "absent"

  actions {
    alternatives {
      path "/usr/lib/jvm/java-8-openjdk/bin/java"
    }
  }
}
```

## Platform Support

| Platform | Implementation | Command Used |
|----------|---------------|--------------|
| Debian/Ubuntu | Full | `update-alternatives --install`, `--set`, `--auto`, `--remove`, `--slave` |
| RedHat/Fedora | Stub | Not yet implemented (structure prepared) |

## Rollback

Changes to alternatives are tracked in the lockfile. The previous alternative state is restored on rollback.
