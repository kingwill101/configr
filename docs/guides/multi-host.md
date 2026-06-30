# Multi-Host Execution

Configr v2 can manage multiple remote machines in a single run. It uses an
**inventory system** to describe hosts, **execution strategies** to control
ordering, and **SSH-mediated remote execution** where the controller runs the
Configr pipeline locally while block file and process operations execute on
each target over SSH/SFTP.

## Overview

```
configr apply --target vm1 --target vm2 --strategy parallel
                    │
                    ▼
            ┌────────────────┐
            │  TargetResolver │  ← inventory { ... }
            └───────┬────────┘
                    │  [vm1, vm2]
                    ▼
            ┌────────────────┐
            │   Strategy      │  ← linear | parallel | serial
            └───────┬────────┘
                    │  for each host:
                    ▼
            ┌──────────────────────┐
            │  applyOnHost(host)   │
            │  ┌────────────────┐  │
            │  │ SSH connect     │  │
            │  │ Local applyV2   │  │
            │  │ Remote FS       │  │
            │  │ Remote process  │  │
            │  └────────────────┘  │
            └──────────────────────┘
                    │
                    ▼
            Per-host lockfile
            config.vm1.lock.json
```

## Inventory

The `inventory { }` block declares the hosts you want to manage. It is parsed
from your i3config file alongside action blocks.

### Syntax

```i3
inventory {
  host "web-01" {
    address = "192.168.1.10"
    port = 22
    user = "root"
    privateKey = "/home/user/.ssh/id_ed25519"
    roles = ["web", "app"]
    groups = ["production", "eu-central"]
  }

  host "db-01" {
    address = "192.168.1.20"
    port = 22
    user = "admin"
    password = "${DB_PASSWORD}"
    roles = ["db"]
    groups = ["production"]
  }
}
```

### Host Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `address` | string | **required** | IP or hostname |
| `port` | int | `22` | SSH port |
| `user` | string | `root` | SSH username |
| `password` | string | `null` | SSH password |
| `privateKey` | string | `null` | Absolute path to PEM private key file |
| `privateKeyPassphrase` | string | `null` | Passphrase for encrypted key |
| `connectTimeout` | int | `30` | Connection timeout (s) |
| `roles` | list | `[]` | Service roles (web, db, worker, ...) |
| `groups` | list | `[]` | Infrastructure groups (production, staging) |

> The `privateKey` field accepts a **file path**. The inventory block reads
> the file contents and passes the PEM key material to the SSH layer.

### Roles and Groups

- **Roles** describe *what* a host does: `web`, `db`, `worker`, `cache`
- **Groups** describe *where* a host is: `production`, `staging`, `us-east`

Both can be used for targeting and for group-level variables.

## Target Resolution

Hosts are selected in this order:

```
1. Explicit host names  (--target web-01 --target web-02)
2. Role names           (--target-role web)
3. Group names          (--target-group production)
4. Default targets      (inventory.default_targets)
5. All hosts            (fallback)
```

### CLI Flags

| Flag | Description |
|------|-------------|
| `--target <name>` | Target a specific host by name (repeatable) |
| `--target-role <role>` | Target all hosts with a role (repeatable) |
| `--target-group <group>` | Target all hosts in a group (repeatable) |
| `--strategy <name>` | Execution strategy: `linear`, `parallel`, `serial` |

### Examples

```bash
# Target specific hosts
configr apply --target web-01 --target web-02

# Target by role
configr apply --target-role db

# Target by group with parallel strategy
configr apply --target-group production --strategy parallel
```

## Execution Strategies

Strategies control the ordering and concurrency of host execution.

### Linear Strategy (default)

Processes hosts **one at a time** in the order they were resolved.

```
web-01 ──▶ apply ──▶ done
web-02 ──▶ apply ──▶ done
db-01  ──▶ apply ──▶ done
```

- If `--fail-fast` is set, stops at the first error
- Otherwise, continues to the next host

```bash
configr apply --target-role web --strategy linear
```

### Parallel Strategy

Processes all hosts **concurrently**.

```
web-01 ──▶ apply ──▶ done
web-02 ──▶ apply ──▶ done     (all at once)
db-01  ──▶ apply ──▶ done
```

- Errors don't stop other hosts unless `--fail-fast`

```bash
configr apply --strategy parallel --target-role worker
```

### Serial Strategy (Boot Groups)

Processes hosts in **priority order** (boot groups). Within each priority
group, hosts run serially. Groups are processed from lowest priority first.

```
Priority 1 (web):     web-01 ──▶ done → web-02 ──▶ done
Priority 10 (db):     db-01  ──▶ done
Priority 20 (worker): worker-01 ──▶ done
```

Priorities can be derived from roles:

| Role | Priority |
|------|----------|
| web, proxy | 1 |
| app | 2 |
| db, redis, cache | 10 |
| worker, job, batch | 20 |
| unknown | 99 |

```bash
configr apply --strategy serial
```

This is the **Kamal-style** deployment strategy — databases come up before
app servers, which come up before workers.

You can implement custom strategies via the plugin system.

## Remote Execution Flow

When a host is targeted, the controller keeps ownership of config parsing,
plugin loading, hook discovery, event reporting, and lockfile writes. The
target host only receives the operations that blocks perform through Configr's
runtime abstractions.

### applyOnHost()

```
1. Parse the config locally and resolve the inventory targets
   └── This pass is dry-run style for multi-host routing

2. SSH: connect(host)
   └── Opens a dartssh2 SSH session and an SFTP-backed FileSystem

3. Run applyV2 locally with remote runtime backends
   └── file blocks use the SFTP FileSystem
   └── execute/script/raw/Lua runCommand use the SSH process backend
   └── host vars are injected into the local processing context

4. Record the result in the per-host lockfile on the controller
```

The remote host does **not** need the Configr binary installed. It needs SSH
access and the operating-system tools that the selected blocks call, such as
`sh`, package managers, or service managers.

### Config, Hook, and Plugin Locality

The config file, Lua plugin files, and hook files are read from the controller
machine. Their side effects use the runtime backend for the current host:

- Standard Lua IO APIs and Configr's `fileExists`, `readFile`, `writeFile`,
  and `appendFile` helpers operate on the remote SFTP file system during SSH
  applies.
- `runCommand(command)` is the process execution API for Lua plugins and hooks
  during SSH applies. It executes through the remote SSH process backend.
- Hook and plugin source paths remain local so the same controller checkout can
  apply to many different hosts without copying executable code to them.

Configr's file helpers are convenience APIs; standard Lua IO can be used when
it expresses the operation cleanly. Command execution is the exception: use
`runCommand(command)` so Configr can route the command through the active
process backend.

### Connection Pool

Connections are cached per host so the same host isn't reconnected if
targeted multiple times.

## Per-Host Lockfiles

Each host gets its own lockfile to track what was applied:

```
<configDir>/<configName>.<hostName>.lock.json
```

For example, `deploy.i3.vm1.lock.json` tracks blocks applied to `vm1`.

### Lockfile Structure

```json
{
  "version": 1,
  "configChecksum": "abc123def456",
  "appliedAt": "2026-06-29T12:00:00Z",
  "appliedBlocks": [
    {
      "blockType": "file",
      "id": "file_0",
      "source": "/tmp/deploy_test",
      "destination": "/tmp/deploy_test",
      "sha256": "aabbcc...",
      "status": "completed",
      "appliedAt": "2026-06-29T12:00:01Z",
      "metadata": { ... }
    }
  ],
  "targets": [
    {
      "hostName": "vm1",
      "succeeded": true,
      "appliedAt": "2026-06-29T12:00:01Z"
    }
  ]
}
```

The consolidated lockfile (`deploy.i3.lock.json`) contains all target entries
alongside the applied blocks for the controller's own execution.

## Remote Rollback

Rollback can target a specific host remotely:

```
configr rollback --host vm1 --count 3
                    │
                    ▼
                    │
         ┌──────────┴──────────┐
         │                     │
    CLI config            Inventory
   (--ssh-host etc.)      auto-resolve
         │                     │
         └──────────┬──────────┘
                    ▼
                    │
    ┌───────────────┼───────────────┐
    │               │               │
 Read lockfile   SSH connect    Local rollbackV2
    │                │          with remote runtime
    │                │          backends
    │               │               │
    └───────────────┴───────────────┘
                    │
              Update/delete
              per-host lockfile
```

### Connection config resolution

The system resolves SSH connection parameters in this order:

1. Explicit `connectionConfig` from CLI flags (`--host`, `--ssh-port`, etc.)
2. Inventory block in the config file (auto-parsed, host looked up by name)
3. Falls back to local rollback if neither is available

Rollback follows the same locality rule as apply: lockfiles and config source
stay on the controller, while block rollback operations use the target host's
SSH-backed file system and process backend.

### CLI Commands

```bash
# Rollback via inventory (auto-resolves SSH config)
configr rollback --config deploy.i3 --v2 --host vm1

# Rollback via explicit SSH flags
configr rollback --v2 --host 192.168.1.10 \
    --ssh-port 2221 --ssh-key ~/.ssh/id_ed25519
```

## Variable Precedence

Configr implements Ansible-style **variable layering** through the
`VariablePrecedence` middleware. Higher priority layers override lower ones:

| Priority | Layer | Source |
|----------|-------|--------|
| 1 (lowest) | `facts` | `gather_facts` block output |
| 2 | `secrets` | Secret providers (password managers) |
| 3 | `groupVars` | Variables attached to groups in inventory |
| 4 | `hostVars` | Per-host variables |
| 5 (highest) | `cliVars` | `--var key=value` CLI flags |

When a block references `${some_var}`, the middleware resolves it by checking
each layer from highest to lowest priority.

## Dependency Checking

Pre-flight dependency checks verify that target hosts are reachable before
execution begins. Define them in your config:

```i3
dependency {
  from = "web-01"
  to = "db-01"
  check_type = "port"
  port = 5432
}
```

Checks are retried with a 2-second interval up to the
specified timeout. Supported check types:

| Type | Method |
|------|--------|
| `ping` | ICMP echo (`ping -c 1`) |
| `port` | TCP connect |
| `network` | Auto-select based on port presence |

## Drift Detection

The system compares per-host lockfiles against the expected state to
find configuration drift:

- Missing lockfile (host was never configured)
- Checksum mismatch (config changed since last apply)
- Block count difference (blocks were added/removed)
- Per-block comparison (type, source, sha256)

This enables drift reporting when running `configr status --v2` across
multiple hosts.

## Test Modes

Configr uses two different integration styles:

- `test/integration/configs/**` is the container-backed sweep. The Configr
  binary is built and run inside the test container, so those configs should
  expect the container's local file system and process environment.
- `test/integration/ssh_integration_test.dart` and the multi-host tests run
  Configr on the controller and target Docker VMs over SSH. Those tests verify
  that file, process, hook, and plugin effects land on the remote hosts without
  copying the Configr binary or config execution to the VMs.

## CLI Reference

### Apply with multi-host flags

```bash
configr apply [--v2] [--config <path>] \
  [--target <host>]...              \
  [--target-role <role>]...         \
  [--target-group <group>]...       \
  [--strategy linear|parallel|serial] \
  [--var key=value]...              \
  [--fail-fast]                     \
  [--dry-run]
```

### Rollback with host targeting

```bash
configr rollback [--v2] [--config <path>] \
  [--host <hostname>]                      \
  [--ssh-port <port>]                      \
  [--ssh-key <path>]                       \
  [--ssh-user <user>]                      \
  [--count <n>]
```
