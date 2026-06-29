# Connection Block

The `connection` block switches later operations to an SSH target. Configr runs
on the local host, but file and process operations execute against the remote
machine.

```i3
connection {
  host = "vm1"
  port = 22
  username = "root"
  private_key = "$sshPrivateKeyPem"
  connect_timeout = 30
}

file {
  path = "/tmp/configr-remote"
  content = "created remotely"
}
```

## Properties

| Property | Default | Description |
|----------|---------|-------------|
| `host` | required | Remote SSH host or IP address |
| `port` | `22` | SSH port |
| `username` | `root` | SSH username |
| `password` | unset | Password authentication value |
| `private_key` | unset | Private key PEM content |
| `private_key_passphrase` | unset | Passphrase for encrypted private keys |
| `connect_timeout` | `30` | Connection timeout in seconds |

`connection` is a configuration block, not an action block. It has no rollback
record of its own. Actions after the block use the remote execution and file
services until another execution backend is registered.

## Notes

- `private_key` is PEM content, not a filesystem path.
- Multi-host inventory entries use `privateKey`; when that value points at a
  local file, Configr reads the file and stores the key content on the host
  model.
- Remote execution does not depend on a platform-local `ssh` CLI.
