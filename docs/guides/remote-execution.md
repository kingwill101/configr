# Remote Execution via SSH

Configr can execute configuration management over SSH, allowing you to
manage remote machines with the same declarative i3config files.

## How It Works

When a remote host is selected, Configr keeps the config on the control machine
and sends file and process operations over SSH/SFTP:

```mermaid
flowchart LR
    CLI[CLI --host flag] --> Config[ConnectionConfig]
    Inline[connection { } block] --> Config
    Config --> SSH[SSH/SFTP session]
    SSH --> Remote[Remote host]
```

## CLI Flags

Global flags to connect to a remote host:

| Flag | Description |
|------|-------------|
| `--host <hostname>` | SSH host to connect to |
| `--ssh-port <port>` | SSH port (default: 22) |
| `--ssh-user <username>` | SSH username (default: root) |
| `--ssh-password <password>` | SSH password |
| `--ssh-key <path>` | Path to SSH private key file |
| `--ssh-key-passphrase <passphrase>` | Passphrase for the private key |

### Examples

```bash
# Connect with password
configr apply --host 192.168.1.100 --ssh-user deploy --ssh-password s3cret

# Connect with SSH key
configr apply --host server.example.com --ssh-key ~/.ssh/id_rsa

# Custom port
configr apply --host db.internal --ssh-port 2222 --ssh-user admin
```

## Inline Connection Block

You can also define the SSH connection inside your i3config file using the
`connection { }` block. Place it at the top of your config — all blocks
after it will execute on the remote host:

```i3
connection {
    host = "server.example.com"
    port = 22
    username = "root"
    private_key = "~/.ssh/id_rsa"
    private_key_passphrase = "opensesame"
    connect_timeout = 30
}

# These blocks run on the remote host
execute {
    command = "hostname"
}

copy {
    source = "local_file.conf"
    destination = "/etc/app.conf"
}
```

### Connection Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `host` | string | **required** | SSH hostname or IP |
| `port` | int | `22` | SSH port |
| `username` | string | `root` | SSH username |
| `password` | string | `null` | SSH password |
| `private_key` | string | `null` | Path or PEM content of private key |
| `private_key_passphrase` | string | `null` | Passphrase for private key |
| `connect_timeout` | int | `30` | Connection timeout in seconds |

## Execution Flow

1. CLI flags or a `connection { }` block select the SSH target.
2. Configr authenticates with a password or private key.
3. File operations use SFTP.
4. Command and package operations execute on the remote host.
5. Remote platform facts are detected from the target.
6. Rollback records are written for the selected host.

### File Transfer

- `putFile(source, dest)` — uploads via SFTP (`SftpFileOpenMode.write | create | truncate`)
- `fetchFile(source, dest)` — downloads via SFTP (`SftpFileOpenMode.read`)

### Command Execution

Commands are serialized to a single string and sent via `session.execute()`.
Shell escaping handles spaces, `$`, and quotes. Environment variables and
working directories are prepended as shell prefixes:

```
cd /working/dir && KEY=value command arg1 arg2
```

## Notes

- Configr does not require the `ssh` CLI to be installed for remote execution.
- The Configr binary is not copied to the remote host.
- Use `--dry-run` with remote flags to preview the selected host workflow.
