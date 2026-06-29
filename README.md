# Configr

Configr is a declarative configuration tool for local machines and SSH
targets. You describe files, packages, services, commands, hooks, secrets, and
multi-host inventories in one config file, then apply or roll back those
changes from the `configr` CLI.

## What It Does

- Applies repeatable configuration blocks for files, templates, packages,
  services, users, groups, cron, firewalls, mounts, HTTP checks, and more.
- Runs locally or against remote hosts over SSH/SFTP without copying the
  Configr binary to the remote machine.
- Tracks successful applies in lockfiles so changes can be rolled back.
- Supports dry runs, named commands, Lua hooks/plugins, secrets, includes, and
  multi-host inventory execution.

## Install

Download a CLI artifact from the latest GitHub Actions run or tagged GitHub
Release. Each archive includes a SHA-256 checksum file.

```bash
tar -xzf configr-linux-x64.tar.gz
shasum -a 256 -c configr-linux-x64.tar.gz.sha256
./configr-linux-x64/configr --version
```

For source builds:

```bash
dart pub get
dart compile exe bin/configr.dart -o configr
./configr --version
```

CI builds embed version, Git SHA, build date, run number, source, and target
metadata. Use `configr --version` to inspect the binary you are running.

## Quick Start

```bash
configr init
configr apply --dry-run
configr apply
configr status
configr rollback --count 1
```

Example `config`:

```i3
include "packages/*.config"

file {
  destination = "~/.config/myapp/settings.toml"
  content = "theme = \"dark\"\n"
  operation = "create"
}

copy {
  source = "dotfiles/bashrc"
  destination = "~/.bashrc"
  backup_original = true
}

commands {
  command "verify" {
    command = "sh"
    parameters "-c" "test -f ~/.bashrc && echo ok"
  }
}
```

Run a named command from the config:

```bash
configr run verify
configr run verify -- --extra-arg
```

## Remote Hosts

Run the same local config against a remote machine:

```bash
configr apply \
  --host server.example.com \
  --ssh-user deploy \
  --ssh-key ~/.ssh/id_ed25519
```

Configr uses SSH/SFTP for remote processes and files. The config stays on the
control machine; file and process operations are routed to the target host.

For multiple hosts, define an inventory and select hosts, roles, or groups from
the CLI. See the docs for inventory, execution strategies, and remote rollback.

## Documentation

- Docs site: <https://kingwill101.github.io/configr/>
- CLI guide: [docs/getting-started/cli-usage.md](docs/getting-started/cli-usage.md)
- Config organization and `include`: [docs/guides/config-organization.md](docs/guides/config-organization.md)
- Remote execution: [docs/guides/remote-execution.md](docs/guides/remote-execution.md)
- Multi-host execution: [docs/guides/multi-host.md](docs/guides/multi-host.md)
- Block reference: [docs/index.md](docs/index.md)

## Development

```bash
dart format --output=none --set-exit-if-changed .
dart analyze
dart test
npm run docs:build
```

Container-backed and SSH integration tests require Docker.

## License

MIT License. See [LICENSE](LICENSE).
