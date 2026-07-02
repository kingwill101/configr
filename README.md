# configr

Configr is a block-based configuration management tool for dotfiles, system
configuration, local automation, and remote host applies. It uses i3config
syntax, executes each v2 block through a common runtime, writes lockfiles for
rollback, and records shell execution audit logs under the project `.configr`
directory.

## Highlights

- **Action blocks** for files, packages, services, users, networking, templates,
  archives, scripts, and assertions.
- **Rollback support** through v2 lockfiles that record applied blocks.
- **Dry runs and fail-fast applies** for safer changes.
- **Remote execution** over SSH with SFTP-backed file operations.
- **Multi-host applies** with inventory targeting, strategies, and per-host
  lockfiles.
- **Cross-platform shell strategies** for POSIX shells, PowerShell, and cmd.
- **Lua plugins and hooks** with local or remote file/process backends.
- **Audit logs** for shell calls and responses in `.configr/logs/shell`.

## Installation

Download a pre-built binary from the
[Releases page](https://github.com/kingwill101/configr/releases), then make it
executable and place it on your `PATH`.

```bash
chmod +x configr
sudo mv configr /usr/local/bin/
```

To build from source:

```bash
dart pub get
dart compile exe bin/configr.dart -o configr
```

## Quick Start

Use v2 action blocks directly for new configs:

```i3
backup {
  source = "~/.bashrc"
  destination = "~/.bashrc.bak"
}

copy {
  source = "dotfiles/bashrc"
  destination = "~/.bashrc"
  overwrite = true
}

permissions {
  source = "~/.bashrc"
  mode = "644"
}
```

Then run:

```bash
configr apply --dry-run
configr apply --fail-fast
configr rollback
```

`--fail-fast` now halts processor execution at the first processor or block
error instead of walking the rest of the config.

## Recommended Config Style

Prefer direct action blocks (`copy {}`, `template {}`, `package {}`, etc.) over
legacy `resource { actions { ... } }` wrappers. Direct blocks are the current v2
execution model and stop propagation cleanly after failures when fail-fast is
enabled.

The legacy resource form is still supported for compatibility:

```i3
resource {
  source = "dotfiles/bashrc"
  destination = "~/.bashrc"

  actions {
    copy {}
    permissions {
      mode = "644"
    }
  }
}
```

Keep this style for existing configs only. For new configs, use explicit blocks
so each operation has its own parsed source location, failure event, lockfile
record, and rollback boundary.

## Common Commands

```bash
configr --help
configr init
configr apply
configr apply --dry-run
configr apply --fail-fast
configr apply --host server.example.com --ssh-user deploy
configr diff
configr status
configr rollback --count 3
configr format
```

## Documentation

- [Documentation index](docs/index.md)
- [CLI usage](docs/getting-started/cli-usage.md)
- [Getting started tutorial](docs/getting-started/tutorial.md)
- [Migration guide](docs/getting-started/migration-guide.md)
- [Architecture](docs/guides/architecture.md)
- [Execution service](docs/guides/execution-service.md)
- [Remote execution](docs/guides/remote-execution.md)
- [Multi-host execution](docs/guides/multi-host.md)
- [Plugin system](docs/guides/plugin-system.md)
- [Windows support](docs/guides/windows.md)

## Development

```bash
dart analyze
dart test
```

Run focused tests while working on a block:

```bash
dart test test/v2/file_test.dart
```

## License

MIT License. See [LICENSE](LICENSE).
