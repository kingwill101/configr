# Multi-Host Execution

Configr v2 can manage multiple remote machines in a single run. It uses an
**inventory system** to describe hosts, **execution strategies** to control
ordering, and **SSH-mediated remote execution** where the controller uploads
config files and runs `configr apply` on each target.

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
            │  │ Upload config   │  │
            │  │ configr apply   │  │
            │  │ (remote)        │  │
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

### Host Model

Internally, each entry becomes a `Host` object:

```dart
class Host {
  final String name;
  final String address;
  final int port;
  final String username;
  final String? privateKey;         // PEM content
  final String? privateKeyPassphrase;
  final int? connectTimeout;
  final Map<String, String> variables;
  final List<String> roles;
  final List<String> groups;
}
```

The `toConnectionMap()` method converts the host to the format expected by
`SSHExecutionService.connect()`.

### Roles and Groups

- **Roles** describe *what* a host does: `web`, `db`, `worker`, `cache`
- **Groups** describe *where* a host is: `production`, `staging`, `us-east`

Both can be used for targeting and for group-level variables.

## Target Resolution

The `TargetResolver` selects which hosts to operate on based on a precedence
chain:

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

- Uses `Future.wait` internally
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

Priorities can be set via the `Target` model or derived from roles:

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

### Strategy Interface

Strategies implement the `ExecutionStrategy` abstract class:

```dart
abstract class ExecutionStrategy {
  String get name;
  String get description;

  Future<void> execute({
    required List<Target> targets,
    required Future<HostExecutionContext> Function(Host) executeOnHost,
    required EventBus globalEventBus,
    bool dryRun = false,
    bool failFast = false,
  });
}
```

You can implement custom strategies via the plugin system.

## Remote Execution Flow

When a host is targeted, the controller does not execute blocks directly on
the remote machine. Instead, it uses a **deploy-and-run** pattern:

### applyOnHost()

```
1. ConnectionPool.acquire(host)
   └── SSHExecutionService.connect(host.toConnectionMap())

2. SSH: putFile(configPath, /tmp/configr_config)
   └── Upload the local i3config file to the remote host

3. SSH: run("configr", ["--config", "/tmp/configr_config",
                         "--v2", "--no-interaction",
                         "apply", (--dry-run)?])
   └── Remote host runs its own configr apply locally
   └── Host vars passed as --var KEY=VAL flags

4. Collect HostExecutionContext (succeeded / errorMessage)
```

The remote host must have the **configr binary** installed at
`/usr/local/bin/configr` (or in `$PATH`).

### Connection Pool

The `ConnectionPool` manages persistent SSH connections:

```dart
class ConnectionPool {
  Future<SSHExecutionService> acquire(Host host);   // get or create
  void release(String hostName);                     // disconnect
  void releaseAll();                                  // disconnect all
}
```

Connections are acquired per-host at the start of `applyOnHost()` and
released after the strategy completes. The pool prevents redundant
connections when the same host is targeted multiple times.

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
ConfigrRuntime.rollbackHost(hostName: 'vm1')
                    │
         ┌──────────┴──────────┐
         │                     │
    CLI config            Inventory
   (--ssh-host etc.)      auto-resolve
         │                     │
         └──────────┬──────────┘
                    ▼
         host_rollback.rollbackHost()
                    │
    ┌───────────────┼───────────────┐
    │               │               │
 Read lockfile   SSH connect    Upload config
    │           SSH run:         SSH run:
    │           configr         configr rollback
    │           apply           --count 3
    │               │               │
    └───────────────┴───────────────┘
                    │
              Update/delete
              per-host lockfile
```

### Connection config resolution

`ConfigrRuntime.rollbackHost()` resolves SSH connection parameters in this
order:

1. Explicit `connectionConfig` from CLI flags (`--host`, `--ssh-port`, etc.)
2. Inventory block in the config file (auto-parsed, host looked up by name)
3. Falls back to local rollback if neither is available

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

The middleware is registered on the i3config processor context before blocks
are processed:

```dart
final varPrecedence = VariablePrecedence()
  ..addSource(PrecedenceLayer.groupVars, groupVars)
  ..addSource(PrecedenceLayer.cliVars, cliVars);
context.variableMiddleware = varPrecedence;
```

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

The `DependencyChecker` retries the check with a 2-second interval up to the
specified timeout. Supported check types:

| Type | Method |
|------|--------|
| `ping` | ICMP echo (`ping -c 1`) |
| `port` | TCP connect |
| `network` | Auto-select based on port presence |

## Drift Detection

The `DriftDetector` compares per-host lockfiles against the expected state to
find configuration drift:

- Missing lockfile (host was never configured)
- Checksum mismatch (config changed since last apply)
- Block count difference (blocks were added/removed)
- Per-block comparison (type, source, sha256)

This enables drift reporting when running `configr status --v2` across
multiple hosts.

## Architecture Summary

```
lib/src/multi_host/
├── host.dart                    Host data model
├── inventory.dart               Inventory container (hosts, roles, groups)
├── inventory_block.dart         i3config parser for inventory { }
├── role.dart                    Role model
├── target.dart                  Target = host + strategy + priority
├── target_resolver.dart         Host selection (name/role/group/fallback)
├── strategy.dart                ExecutionStrategy interface
├── strategies/
│   ├── linear_strategy.dart     One host at a time
│   ├── parallel_strategy.dart   All hosts concurrently
│   └── serial_strategy.dart     Priority-ordered boot groups
├── strategy_resolver.dart       Strategy name → implementation
├── connection_pool.dart         Persistent SSH connection manager
├── host_applier.dart            Remote apply on a single host
├── host_rollback.dart           Per-host lockfile + remote rollback
├── host_execution_context.dart  Per-host result carrier
├── host_lock.dart               Directory-based deploy locks
├── host_vars.dart               Cross-host fact access (hostvars)
├── variable_precedence.dart     Ansible-style variable layering
├── dependency_checker.dart      Pre-flight host reachability checks
├── drift_detector.dart          Config drift detection
├── boot_group.dart              Kamal-style boot group config
└── host_event.dart              Host-level event types

lib/src/
├── configr_runtime.dart         CLI facade (apply, rollback, rollbackHost)
├── connection_config.dart       SSH connection config model
└── blocks/
    ├── v2_apply.dart            Orchestrator (applyV2, rollbackV2)
    └── di_setup.dart            Core DI service registration
```

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
