# Overview

Configr is a command-line tool for applying repeatable configuration to local
machines and SSH targets.

You write a `config` file with blocks such as `copy`, `file`, `template`,
`package`, `service`, `commands`, `secrets`, and `inventory`. Configr reads the
file, previews or applies the requested changes, and records successful work in
a lockfile so it can be rolled back later.

## What You Can Manage

- Dotfiles and application config files
- Generated files and templates
- Packages and package-manager-specific installs
- Services, users, groups, cron jobs, firewalls, mounts, and sysctl settings
- Remote hosts over SSH/SFTP
- Multi-host inventories with roles and groups
- Secrets, hooks, named commands, and Lua plugins

## Basic Workflow

```bash
configr init
configr apply --dry-run
configr apply
configr status
configr rollback --count 1
```

## Example Config

```i3
include "packages/*.config"

copy {
  source = "dotfiles/bashrc"
  destination = "~/.bashrc"
  backup_original = true
}

template {
  source = "templates/app.conf.liquid"
  destination = "~/.config/myapp/app.conf"
}

commands {
  command "verify" {
    command = "sh"
    parameters "-c" "test -f ~/.bashrc && echo ok"
  }
}
```

## Where To Go Next

- [Tutorial](tutorial.md) - create and apply a first config
- [CLI Usage](cli-usage.md) - command reference and examples
- [Config Organization](../guides/config-organization.md) - split configs across files
- [Remote Execution](../guides/remote-execution.md) - apply to SSH hosts
- [Block Reference](../index.md#action-blocks) - all available blocks
