# Multi-Host Support Plan: Kamal + Ansible Patterns

## Executive Summary

configr currently operates on a **single host** model:
- One `ExecutionService` (local or SSH) registered in the DI container
- One lockfile tracking applied blocks
- One `EventBus` for all events
- Blocks execute sequentially on whichever host the `connection` block selects

We want to support **both** deployment philosophies:
1. **Kamal**: Docker-centric, role-based, serial boot groups for zero-downtime deploys
2. **Ansible**: Agentless, task-centric, strategy plugins (linear/free) for orchestration

This plan preserves configr's i3config syntax while adding host abstraction layers.

---

## Current Architecture (Single-Host Flow)

```
ConfigrRuntime.apply()
  → applyV2(configPath)
    → Parse i3config
    → Register ActionBlock handlers (singleton per type)
    → Register ConnectionBlock (swaps DI ExecutionService to SSH)
    → processor.process(config)
      → For each block: read properties → execute → record in lockfile
    → Write lockfile (<config>.lock.json)
```

**Key coupling points**:
- `ActionBlock.executionService` resolves from DI singleton
- `V2LockfileManager` writes one lockfile per config path
- `EventBus` is global, no host scoping
- `ConnectionBlock` is imperative (must appear before dependent blocks)

---

## Target Architecture (Multi-Host)

```
ConfigrRuntime.apply(targets: [...])
  → applyV2MultiHost(configPath, targets)
    → Load HostInventory from inventory block / CLI args / config
    → For each target:
      → Create HostExecutionContext (executionService, lockfile, eventBus scope)
      → strategy.execute(target, executeOnHost)
        → Linear:  one host at a time, all blocks
        → Parallel: all hosts concurrently, all blocks
        → Serial:  boot groups (web first, then workers)
    → Write consolidated lockfile
```

---

## Phase 0: Foundation (Weeks 1-2)

### 0.1 Host Inventory Abstraction

**New files**:
- `lib/src/multi_host/host.dart` — Host model
- `lib/src/multi_host/inventory.dart` — Inventory loader
- `lib/src/multi_host/role.dart` — Role model (Kamal-style)
- `lib/src/multi_host/target.dart` — Execution target

**Host model**:
```dart
class Host {
  final String name;           // "web-01", "db-master"
  final String address;        // IP or hostname
  final int port;
  final String username;
  final String? privateKey;
  final Map<String, String> variables;  // hostvars
  final List<String> roles;     // ["web", "app"]
  final String? group;          // "production", "staging"
}
```

**Role model** (Kamal):
```dart
class Role {
  final String name;           // "web", "worker", "db"
  final List<Host> hosts;
  final bool primary;          // primary role boots first in serial strategy
  final int bootPriority;      // lower = boots first
}
```

**Inventory loading** (hierarchical, like Ansible):
- `inventory { }` block in i3config (flat list or INI-style groups)
- `.configr/inventory.yml` or `.configr/hosts/` directory
- CLI `--host web-01`, `--hosts web-01,web-02`, `--role web`
- Kamal-style `servers { web { hosts: [10.0.0.1] } }` block

**Inventory block syntax** (i3config):
```i3
# Simple list
inventory {
  host "web-01" address = "10.0.0.1" username = "root"
  host "web-02" address = "10.0.0.2" username = "root"
  host "db-01"  address = "10.0.0.3" username = "root" roles = ["db"]
}

# Role-based (Kamal-style)
servers {
  web { hosts = ["10.0.0.1", "10.0.0.2"] }
  db  { hosts = ["10.0.0.3"] }
}

# Grouped hosts (Ansible-style)
group "production" {
  host "web-01" address = "10.0.0.1"
  host "web-02" address = "10.0.0.2"
}
group "staging" {
  host "web-01" address = "10.0.1.1"
}
```

### 0.2 Host Scoped Execution Context

**New file**: `lib/src/multi_host/host_execution_context.dart`

```dart
class HostExecutionContext {
  final Host host;
  final ExecutionService executionService;  // SSH connected to this host
  final EventBus eventBus;                  // scoped or tagged
  final String lockfilePath;                // per-host lockfile
  final Map<String, String> hostVariables;  // resolved facts/hostvars
  final List<AppliedBlockRecord> appliedBlocks;

  Future<void> connect();
  Future<void> disconnect();
}
```

Each host gets its own:
- Connected `SSHExecutionService` (reused across all blocks for that host)
- Lockfile: `<config>.<host>.lock.json` (Kamal uses mkdir, we use files)
- EventBus scope with `host` tag on all events

### 0.3 DI Scoping for Multi-Host

**Problem**: `di<ExecutionService>()` is a global singleton.

**Solution**: Add a thread-local-style scoping mechanism using GetIt's scoping OR a simpler overlay:

```dart
class HostScope {
  final String hostName;
  final ExecutionService executionService;
  final EventBus eventBus;

  void enter() {
    di.allowReassignment = true;
    di.registerSingleton<ExecutionService>(executionService);
    di.registerSingleton<EventBus>(eventBus);
    di.allowReassignment = false;
  }

  void exit() {
    // Restore previous ExecutionService (local or previous host)
  }
}
```

**Alternative (simpler)**: Pass `executionService` explicitly through `ActionBlock` rather than DI.

Decision: **Pass explicitly** — avoids GetIt scoping complexity and makes testing easier.

---

## Phase 1: Inventory & Target Selection (Weeks 2-3)

### 1.1 Inventory Block Handler

**New file**: `lib/src/blocks/inventory_block.dart`

Implements `i3.BlockHandler` to collect host definitions from config:
- Parses `host "name" { ... }` and `servers { ... }` blocks
- Populates `HostInventory` singleton
- Supports `connection` block properties as host defaults

### 1.2 Target Resolution

**New file**: `lib/src/multi_host/target_resolver.dart`

Resolves which hosts to operate on from (in precedence order):
1. CLI flags: `--host web-01`, `--hosts web-01,web-02`, `--role web`
2. Inventory block `default_targets` property
3. All hosts in inventory

```dart
class TargetResolver {
  List<Host> resolve({
    List<String>? hosts,
    List<String>? roles,
    List<String>? groups,
    Inventory? inventory,
  });
}
```

### 1.3 CLI Extensions

**File**: `lib/src/cli/commands/apply.dart` additions

```dart
argParser.addMultiOption('host', ...);
argParser.addMultiOption('role', ...);
argParser.addMultiOption('group', ...);
argParser.addOption('strategy', ...); // 'linear' | 'parallel' | 'serial'
```

New CLI command: `configr hosts` — list inventory hosts/roles.

---

## Phase 2: Strategy Plugins (Weeks 3-5)

### 2.1 Strategy Interface

**New file**: `lib/src/multi_host/strategy.dart`

```dart
abstract class ExecutionStrategy {
  String get name;
  String get description;

  Future<void> execute({
    required List<Host> targets,
    required Future<void> Function(Host) executeOnHost,
    required EventBus globalEventBus,
    required bool dryRun,
    required bool failFast,
  });
}
```

### 2.2 Linear Strategy (Ansible Default)

```dart
class LinearStrategy implements ExecutionStrategy {
  @override
  Future<void> execute(...) async {
    for (final host in targets) {
      await executeOnHost(host);
      if (failFast && _hasErrors) break;
    }
  }
}
```

Block-by-block across all hosts:
```
Host A: copy → file → service
Host B: copy → file → service
Host C: copy → file → service
```
(A waits for all blocks before B starts)

### 2.3 Serial Strategy with Boot Groups (Kamal)

```dart
class SerialStrategy implements ExecutionStrategy {
  final Map<String, List<Host>> bootGroups; // {"web": [...], "worker": [...]}

  @override
  Future<void> execute(...) async {
    for (final group in bootGroups.entries.sortedByPriority()) {
      final groupHosts = targets.where((h) => group.value.contains(h)).toList();
      for (final host in groupHosts) {
        await executeOnHost(host);
      }
      // Wait for health checks before proceeding (optional Kamal barrier)
      await _waitForGroupHealth(group.key);
    }
  }
}
```

Boot group ordering:
1. Primary role (web) — ensures app is serving
2. Proxy/load balancer — ensures traffic routing
3. Workers/secondary roles

**i3config syntax**:
```i3
strategy {
  type = "serial"
  boot_group "web"     hosts = ["web-01", "web-02"]
  boot_group "proxy"   hosts = ["proxy-01"]
  boot_group "worker"  hosts = ["worker-01"]
}
```

### 2.4 Parallel Strategy (Free)

```dart
class ParallelStrategy implements ExecutionStrategy {
  @override
  Future<void> execute(...) async {
    await Future.wait(
      targets.map((h) => executeOnHost(h)),
    );
  }
}
```

### 2.5 Strategy Selection

Auto-selected based on config:
- `strategy { type = "serial" }` or `boot_group` blocks → `SerialStrategy`
- `--parallel` CLI flag → `ParallelStrategy`
- Default → `LinearStrategy` (Ansible-compatible, safest)

---

## Phase 3: Per-Host Config Processing (Weeks 4-6)

### 3.1 Host-Scoped applyV2

**New file**: `lib/src/multi_host/host_applier.dart`

```dart
Future<void> applyOnHost(Host host, String configPath, HostExecutionContext ctx) async {
  // Parse config once, reuse AST for all hosts
  final config = await _parseConfig(configPath);

  // Create per-host processor with host variables
  final processor = i3.ConfigProcessor(fileSystem: ...);
  ctx.hostVariables.forEach((k, v) => processor.context.setVariable(k, v));

  // Register blocks with host-scoped executionService
  await _registerAllBlocks(processor, executionService: ctx.executionService, ...);

  // Process blocks — same AST, different execution backend
  await processor.process(config);

  // Write per-host lockfile
  await V2LockfileManager(ctx.lockfilePath).write(...);
}
```

**Key design decision**: Parse config **once**, execute N times (once per host). This:
- Avoids redundant parsing
- Ensures consistent block IDs across hosts
- Matches Ansible's playbook-parsed-once model

### 3.2 Host Variables (hostvars)

Ansible's `hostvars` magic allows referencing other hosts' variables:
```yaml
# Ansible
{{ hostvars['db-01'].ansible_host }}
```

configr equivalent in i3config:
```i3
secrets {
  db_password = "secret:db_pass"
}

copy {
  source = "/app/config.template"
  destination = "/app/config.json"
  content = """
  DB_HOST = {{ hostvars['db-01'].address }}
  DB_PASS = {{ secrets.db_password }}
  """
}
```

**Implementation**:
- Inject `hostvars` as a lazy-access variable in the processor context
- Resolve at template-render time, not parse time
- Template blocks call `hostvars[hostName].address` via SecretResolver-style lookup

### 3.3 Connection Management

Kamal opens one persistent SSH connection per host for the entire deploy:
- `SSHExecutionService` connects once, reuses for all blocks
- configr already does this per `connection` block, but needs pooling for multi-host

**New file**: `lib/src/multi_host/connection_pool.dart`

```dart
class HostConnectionPool {
  final Map<String, SSHExecutionService> _connections = {};

  Future<SSHExecutionService> acquire(Host host) async {
    if (!_connections.containsKey(host.name)) {
      final ssh = SSHExecutionService();
      await ssh.connect(host.toMap());
      _connections[host.name] = ssh;
    }
    return _connections[host.name]!;
  }

  Future<void> release(Host host) async {
    await _connections[host.name]?.disconnect();
    _connections.remove(host.name);
  }

  Future<void> releaseAll() async { ... }
}
```

### 3.4 Lockfile Consolidation

Kamal uses mkdir-based locks (`.kamal/locks/<host>`). configr uses JSON lockfiles.

**Hybrid approach**:
- Per-host lockfiles: `<config>.<host>.lock.json` (for rollback per host)
- Consolidated manifest: `<config>.lock.json` (for cross-host status)

```json
{
  "version": 2,
  "config_checksum": "abc123",
  "targets": {
    "web-01": { "lockfile": "config.web-01.lock.json", "status": "completed" },
    "web-02": { "lockfile": "config.web-02.lock.json", "status": "failed" }
  },
  "applied_at": "2024-01-15T10:00:00Z"
}
```

---

## Phase 4: Orchestration & Observability (Weeks 6-7)

### 4.1 Host-Scoped Events

Annotate every `EventBus` event with host context:
```dart
class HostedModuleEvent extends ModuleEvent {
  final String hostName;
  final HostStatus hostStatus;

  @override
  ModuleEvent withMetadata(Map<String, dynamic> extra) =>
      HostedModuleEvent(
        hostName: hostName,
        hostStatus: hostStatus,
        ...
      );
}
```

Event types needed:
- `HostStartedEvent` — host execution begins
- `HostCompletedEvent` — all blocks on host succeeded
- `HostFailedEvent` — host execution failed
- `BlockSkippedEvent` — block skipped due to fail-fast on prior host

### 4.2 Rollback Per Host

```dart
Future<void> rollbackHost(String hostName, {int? count}) async {
  final lockfilePath = '$configPath.$hostName.lock.json';
  await rollbackV2(lockfilePath, count: count);
}
```

CLI: `configr rollback --host web-01` or `configr rollback --all`.

### 4.3 Drift Detection Across Fleet

Extend drift detection to compare per-host lockfiles:
```i3
drift {
  target = "web-*"        # glob against host names
  check = ["config.md5", "service.version"]
}
```

---

## Phase 5: Kamal-Specific Docker Features (Weeks 7-9)

Kamal's value proposition is Docker deployment. configr can support Docker-centric blocks:

### 5.1 Container-Aware Blocks

New block types:
- `container { image = "nginx:latest" name = "web" host = "web-01" }`
- `container_exec { container = "web" command = "nginx -s reload" }`
- `container_logs { container = "web" tail = 100 }`

These map to Kamal's `Commands::Container`, `Commands::App`, etc.

### 5.2 Boot Group Validation

```i3
boot {
  group "web" {
    hosts = ["web-01", "web-02"]
    health_check = "curl -f http://localhost:8080/health"
    max_parallel = 2
  }
  group "worker" {
    hosts = ["worker-01", "worker-02"]
    depends_on = ["web"]     # waits for web group to finish
  }
}
```

### 5.3 Multi-Host Locking (mkdir-based)

Port Kamal's mkdir lock to lockfile:
```dart
Future<void> acquireHostLock(String hostName) async {
  final lockDir = p.join('.configr', 'locks', hostName);
  // Atomic mkdir (fails if exists)
  await fs.directory(lockDir).create();
}

Future<void> releaseHostLock(String hostName) async {
  final lockDir = p.join('.configr', 'locks', hostName);
  await fs.directory(lockDir).delete();
}
```

---

## Phase 6: Ansible-Specific Features (Weeks 9-11)

### 6.1 Facts Gathering

```i3
gather_facts {
  destination = ".configr/facts/web-01.json"
  facts = ["os", "network", "packages"]
}
```

Facts stored per host, available as `hostvars['web-01'].facts.os`.

### 6.2 Strategy Plugin Interface (Public)

Allow users to write custom strategies:

```dart
abstract class ExecutionStrategy {
  Future<void> execute({
    required List<Host> targets,
    required HostExecutor executeOnHost,
  });
}

class CanaryStrategy implements ExecutionStrategy {
  final int percentage;
  CanaryStrategy(this.percentage);

  @override
  Future<void> execute(...) async {
    // Deploy to 10% of hosts, wait, then roll out rest
  }
}
```

### 6.3 Delegate To (Ansible `delegate_to`)

```i3
execute {
  script = "setup_db.sh"
  delegate_to = "db-admin-host"    # runs on different host than current target
}
```

Implementation: block-level override of executionService within a host's processing.

### 6.4 Variable Precedence (Ansible)

configr already has variable resolution. Add precedence tiers:
1. Command line `--var key=value`
2. Inventory host vars
3. Group vars
4. Config `set_fact` blocks
5. Secrets
6. System facts

---

## Phase 7: Polish & Integration (Weeks 11-12)

### 7.1 Unified Status Command

```
configr status
  Shows per-host status across all targets

configr status --host web-01
  Shows detailed lockfile + facts for single host
```

### 7.2 Consolidated Diff

```
configr diff --target web-01,web-02
  Shows config + live state diff for each host
```

### 7.3 Cross-Host Dependencies

```i3
dependency {
  from = "web-01"
  to   = "db-01"
  type = "network"     # wait for network reachability
  timeout = 60
}
```

---

## File Inventory Summary

### New Files (~40 files)

**Phase 0 (Foundation)**:
- `lib/src/multi_host/host.dart`
- `lib/src/multi_host/role.dart`
- `lib/src/multi_host/inventory.dart`
- `lib/src/multi_host/target.dart`
- `lib/src/multi_host/host_execution_context.dart`

**Phase 1 (Inventory)**:
- `lib/src/blocks/inventory_block.dart`
- `lib/src/blocks/servers_block.dart`
- `lib/src/multi_host/target_resolver.dart`

**Phase 2 (Strategy)**:
- `lib/src/multi_host/strategy.dart`
- `lib/src/multi_host/strategies/linear_strategy.dart`
- `lib/src/multi_host/strategies/serial_strategy.dart`
- `lib/src/multi_host/strategies/parallel_strategy.dart`

**Phase 3 (Per-Host Execution)**:
- `lib/src/multi_host/host_applier.dart`
- `lib/src/multi_host/connection_pool.dart`
- `lib/src/multi_host/host_variables.dart`

**Phase 4 (Orchestration)**:
- `lib/src/multi_host/orchestrator.dart`
- `lib/src/events/host_events.dart`

**Phase 5 (Kamal)**:
- `lib/src/blocks/container_block.dart`
- `lib/src/blocks/container_exec_block.dart`
- `lib/src/multi_host/boot_group.dart`

**Phase 6 (Ansible)**:
- `lib/src/multi_host/facts_gatherer.dart`
- `lib/src/multi_host/variable_precedence.dart`

**Phase 7 (Polish)**:
- `lib/src/multi_host/dependency_checker.dart`

### Modified Files (~15 files)

- `lib/src/blocks/v2_apply.dart` — add `applyV2MultiHost` entry point
- `lib/src/configr_runtime.dart` — add `targets`, `strategy` parameters
- `lib/src/blocks/action_block.dart` — pass `executionService` explicitly
- `lib/src/blocks/connection_block.dart` — integrate with connection pool
- `lib/src/utils/event_bus.dart` — add `HostedModuleEvent`
- `lib/src/utils/v2_lockfile_manager.dart` — per-host lockfiles
- `lib/src/models/v2_lockfile_data.dart` — consolidated manifest
- `lib/src/cli/commands/apply.dart` — multi-host CLI flags
- `lib/src/cli/commands/rollback.dart` — per-host rollback
- `lib/src/cli/commands/status.dart` — per-host status

---

## Testing Strategy

### Unit Tests
- `test/multi_host/host_test.dart`
- `test/multi_host/inventory_test.dart`
- `test/multi_host/strategy_test.dart`
- `test/multi_host/target_resolver_test.dart`

### Integration Tests
- `test/integration/multi_host/linear_apply_test/`
- `test/integration/multi_host/serial_boot_test/`
- `test/integration/multi_host/parallel_apply_test/`

### Example Configs
- `examples/multi_host/basic/` — 2 hosts, linear strategy
- `examples/multi_host/serial_deploy/` — Kamal-style boot groups
- `examples/multi_host/inventory/` — INI-style inventory file

---

## Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| Breaking single-host API | `applyV2` unchanged; new `applyV2MultiHost` function |
| DI singleton coupling | Phase 0.3: Pass executionService explicitly before adding host scoping |
| Lockfile migration | Phase 3.4: New format, backward-compatible reader |
| Config syntax overload | Phase 1: inventory block is optional; CLI flags work without it |
| SSH connection storms | Phase 3.3: ConnectionPool with configurable max concurrent |

---

## Kanban-Sized Work Units

**M0** (skeleton):
- [ ] Host + Inventory models
- [ ] TargetResolver with CLI integration
- [ ] LinearStrategy (sequential, one host at a time)

**M1** (core multi-host):
- [ ] HostExecutionContext + ConnectionPool
- [ ] applyOnHost using existing ActionBlock pipeline
- [ ] Per-host lockfiles + consolidated manifest
- [ ] Host-scoped events

**M2** (Kamal parity):
- [ ] SerialStrategy with boot groups
- [ ] mkdir-based host locks
- [ ] container blocks

**M3** (Ansible parity):
- [ ] hostvars / host variables
- [ ] Facts gathering
- [ ] Variable precedence tiers

**M4** (polish):
- [ ] Canary/blue-green strategies
- [ ] Dependency checks between hosts
- [ ] status/diff/rollback per-host

---

## Why This Approach

1. **Preserves configr's identity**: i3config syntax stays, no YAML migration
2. **Dual heritage**: Linear strategy = Ansible default feel; Serial with boot groups = Kamal deploy feel
3. **Incremental**: Each phase is independently useful
4. **Testable**: Host scoping via explicit parameters (not DI magic) enables fast MemoryFileSystem tests
5. **Composable**: Users pick strategy per-command, not globally
