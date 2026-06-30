# Remote Execution via SSH

Configr v2 can execute configuration management over SSH, allowing you to
manage remote machines with the same declarative i3config files.

Configr runs the configuration pipeline on the controller. Config files, hook
files, plugin files, event reporting, and lockfile writes stay local. Block
file operations and process operations use the active runtime backend; with
SSH that backend is dartssh2 plus SFTP.

## Architecture

The `ExecutionService` abstraction sits between block handlers and the
operating system. Two implementations exist:

- **`LocalExecutionService`** — runs commands and file operations on the
  local machine via `dart:io` `Process.run` / `Process.start`
- **`SSHExecutionService`** — runs commands and file operations on a remote
  machine over SSH/SFTP using `dartssh2`

For direct `--host` or `connection { }` runs, the DI container selects which
transport to use based on the presence of a `host` key in the connection
configuration:

```mermaid
flowchart LR
    CLI[CLI --host flag] --> Config[ConnectionConfig]
    Inline[connection { } block] --> Config
    Config --> DI[DI: ExecutionService]
    DI --> Local[LocalExecutionService]
    DI --> SSH[SSHExecutionService]
    SSH --> SSH2[dartssh2]
    SSH2 --> Remote[Remote host]
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
configr apply --v2 --host 192.168.1.100 --ssh-user deploy --ssh-password s3cret

# Connect with SSH key
configr apply --v2 --host server.example.com --ssh-key ~/.ssh/id_rsa

# Custom port
configr apply --v2 --host db.internal --ssh-port 2222 --ssh-user admin
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

# These blocks use the remote host's process and file-system backends
execute {
    command = "hostname"
}

file {
    file_path = "/tmp/configr_remote_test"
    content = "written on the remote host"
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

## How It Works

1. CLI flags or a `connection { }` block produce a `ConnectionConfig` map
2. `_registerAllBlocks()` checks for a non-empty `host` key
3. If present, it creates an `SSHExecutionService` and calls `connect()`
4. The SSH service opens a TCP socket via `SSHSocket.connect()`
5. Authentication uses password (`onPasswordRequest`) or key pair
   (`SSHKeyPair.fromPem()` → `identities`)
6. After `await client.authenticated`, an SFTP channel opens for file transfers
7. Remote platform is detected via `uname -s`
8. Block handlers receive the SSH-backed execution service and file system
9. All `run()`, `putFile()`, `fetchFile()`, and runtime file-system calls go
   over the SSH/SFTP session

The remote machine does not need Configr installed. It only needs SSH access
and any operating-system tools required by the blocks being applied.

For multi-host inventory runs, Configr first resolves targets locally. It then
opens one SSH runtime per target host and calls the same local apply pipeline
with that host's remote file system and process backend.

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

Lua plugins and Lua hooks should use Configr's `runCommand(command)` helper
for command execution. File IO can use standard Lua IO or Configr's file
helpers, but command execution is routed through Configr's active process
backend via `runCommand(command)`, including SSH remotes.

## SSHExecutionService API

```dart
class SSHExecutionService implements ExecutionService {
  Future<void> connect(Map<String, dynamic> config);
  Future<void> disconnect();
  bool get isConnected;
  String get platform;       // "linux", "macos", "windows"
  String get remoteHost;

  Future<ProcessResult> run(
    String command,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
    Map<String, String>? environment,
    CommandOutputHandler? onOutput,
    String? stdin,
  });

  Future<void> putFile(String sourcePath, String destinationPath);
  Future<void> fetchFile(String sourcePath, String destinationPath);
}
```
