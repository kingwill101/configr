# Research: Ansible Architecture vs Configr
**Date:** 2026-06-27  
**Scope:** Deep dive into Ansible's multi-host architecture, execution model, and key design patterns. Competitive comparison with configr, focusing on gaps and opportunities.

---

## 1. Executive Summary

**Ansible** (Python, ~60k LOC) is a mature agentless configuration management and orchestration engine targeting fleets of hosts via SSH.  
**configr** (Dart, ~15k LOC) is a single-host configuration management tool for dotfiles and system configuration with an i3config-inspired declarative syntax.

**The fundamental difference:**  
- Ansible operates on **N hosts** in a single run using an inventory-driven model with pluggable strategies, host variables, facts, and parallel execution.  
- configr operates on **1 host** per invocation. It supports SSH transport but has no inventory, grouping, host abstraction, or target iteration. Multi-host management requires external orchestration (shell loops, scripts).

**Key takeaway:** configr's execution abstractions (`ActionBlock` + `ExecutionService`) are architecturally sound and extensible. The missing layer is **multi-target coordination**: inventory, host variables, facts, strategies, and per-host execution loops.

---

## 2. How Ansible Handles Multiple Hosts

### 2.1 Inventory System

Ansible's inventory is the single source of truth for what hosts exist and how they are grouped.

**Core implementation:**  
- `lib/ansible/inventory/data.py` — `InventoryData` holds raw host/group dictionaries. Always creates implicit `all` and `ungrouped` groups.  
- `lib/ansible/inventory/manager.py` — `InventoryManager` is the top-level API. Parses INI/YAML sources, resolves host patterns, and provides `get_hosts()` for pattern-limited subsets.  
- `lib/ansible/inventory/host.py` — `Host` objects carry variables, group membership, and magic variables (`inventory_hostname`, `group_names`).  
- `lib/ansible/inventory/group.py` — `Group` objects support hierarchical parent/child relationships, group vars, depth, and priority.

**Host pattern matching (`get_hosts()`):**  
- Comma/colon-separated lists (`web,db`)  
- Shell globs (`foo*`), regex (`~pattern`), group names  
- Subscript ranges (`web[1:3]`) for subset selection  
- Special modifiers: `!pattern` (exclude), `&pattern` (intersection)  
- Order options: `sorted`, `reverse_sorted`, `shuffle`, `inventory`, `reverse_inventory`  
- `_subset` applies `--limit` restrictions; `_restriction` filters failed/unreachable hosts

**Variable resolution order (highest precedence wins):**
1. Role defaults (lowest)
2. Group vars from inventory (`group_vars/`)
3. Host vars from inventory (`host_vars/`)
4. Play vars
5. `vars_files` entries
6. Role exported vars
7. Registered vars / `set_fact` / `include_vars` cache
8. Extra vars (`-e`) (highest)

**Magic variables:**  
- `inventory_hostname`, `group_names`, `hostvars`, `groups`, `ansible_play_hosts`, `ansible_play_batch`, `playbook_dir`

---

### 2.2 Playbook Structure

A playbook is a list of **plays**. Each play targets a specific set of hosts and defines the work to perform.

**Key classes in `lib/ansible/playbook/`:**  
- `Playbook` — Top-level container; loads plays or `import_playbook` includes  
- `Play` — One execution unit: `hosts`, `vars`, `roles`, `pre_tasks`, `tasks`, `post_tasks`, `handlers`, `serial`  
- `Task` — Atomic work unit: `action`, `args`, `when`, `loop`, `register`, `delegate_to`, `become`, `async_val`, `poll`  
- `Block` — Container with `block`, `rescue`, `always` sections (try/except/finally semantics)  
- `Role` — Reusable unit with directory layout (`tasks/`, `handlers/`, `vars/`, `defaults/`, `meta/`, `files/`, `templates/`)

**Play compilation (`Play.compile()`):**  
Merges `pre_tasks` → role tasks (recursive dependencies first) → `tasks` → `post_tasks`, with `flush_handlers` meta tasks inserted between sections.

**Task control flow attributes:**  
- `when` — conditional execution per task  
- `loop` / `with_*` — iteration (loaded via lookup plugins)  
- `register` — captures result into host-specific variable cache  
- `changed_when` / `failed_when` — post-execution result evaluation  
- `until` + `retries` + `delay` — retry loops  
- `delegate_to` — run task on a different host  
- `run_once` / `BYPASS_HOST_LOOP` — execute once, not per host  
- `async_val` + `poll` — background execution with async polling

---

### 2.3 Execution Model

Ansible's execution engine runs tasks across multiple hosts using a **multi-process fork pool** with pluggable concurrency strategies.

#### High-Level Flow
```
PlaybookExecutor
  → TaskQueueManager (multiprocessing orchestrator)
    → Strategy Plugin (linear/free/host_pinned)
      → WorkerProcess (fork pool, up to --forks)
        → TaskExecutor
          → Action Plugin
            → Connection Plugin
              → Remote Module Execution
```

#### PlaybookExecutor
Entry point. Iterates plays, splits hosts into **serialized batches** (`_get_serialized_batches()`):  
- `serial: 1` → one host at a time  
- `serial: 50%` → percentage-based batches  
- `serial: [1, 5, 10]` → progressive escalation  
- Default (no serial) → all hosts simultaneously  
Generates retry files for failed hosts.

#### TaskQueueManager (TQM)
- Creates a pool of `WorkerProcess` forks (controlled by `--forks`)  
- Manages `FinalQueue` (multiprocessing `SimpleQueue`) for inter-process communication  
- Dispatches to **callback plugins** for output formatting and event handling  
- Tracks `_failed_hosts`, `_unreachable_hosts`  
- Handles SIGTERM/SIGINT propagation to workers

#### PlayIterator
- Maintains **per-host `HostState`** tracking execution position  
- State machine: `SETUP` → `VALIDATE` → `TASKS` → `RESCUE` → `ALWAYS` → `HANDLERS` → `COMPLETE`  
- Supports nested child states for blocks  
- `get_next_task_for_host()` advances each host **independently**  
- Enables both linear (lockstep) and free (independent) strategies

#### TaskExecutor (inside WorkerProcess)
Per-task lifecycle:
1. Evaluate loop items (`with_*` or `loop`)  
2. Calculate `delegate_to` target  
3. Post-validate task and resolve connection  
4. Load action plugin handler  
5. Execute handler  
6. Handle async polling if `async_val > 0`  
7. Evaluate `changed_when` / `failed_when` / `until`  
8. Collect `UnifiedTaskResult`

#### Strategy Plugins
- **Linear (`linear.py`)** — Lockstep execution: all hosts complete task N before any start task N+1. Implements `run_once`, `any_errors_fatal`, `max_fail_percentage`.  
- **Free (`free.py`)** — Per-host independent progression. Hosts execute tasks as fast as possible. Supports `throttle` (limits concurrent executions) and `host_pinned` (affinity-based).  
- **Host Pinned (`host_pinned.py`)** — Pins specific hosts to specific workers for affinity.

---

### 2.4 Facts & Hostvars

Ansible automatically gathers **facts** (system information) via the `setup` module unless disabled.

**Fact implementation:**  
- Facts are cached in `_fact_cache` (keyed by hostname)  
- `namespace_facts()` wraps facts under `ansible_facts` key  
- `ansible_local` facts are always promoted (from `setup` module or `set_fact`)  
- Fact caching is pluggable (`cache_loader.get(C.CACHE_PLUGIN)`)  

**`hostvars` magic variable (`lib/ansible/vars/hostvars.py`):**  
- A lazy `Mapping` that retrieves another host's full variable set when accessed  
- Enables cross-host orchestration: "fetch value from host A and use it on host B"  
- Supports `ansible_delegated_vars` for `delegate_to` variable resolution

**Delegation:**  
- `get_delegated_vars_and_hostname()` resolves `delegate_to`  
- Creates `ansible_delegated_vars[hostname]` with full vars for the delegated host  
- `delegate_facts` controls whether facts return to original or delegated host

---

### 2.5 Plugin Architecture

Ansible is **almost entirely plugin-driven**. Plugin types in `lib/ansible/plugins/`:

| Type | Loader | Purpose |
|------|--------|---------|
| `action` | `action_loader` | Orchestrates task execution |
| `connection` | `connection_loader` | Transport to remote host (ssh, local, winrm, psrp) |
| `become` | `become_loader` | Privilege escalation (sudo, su, etc.) |
| `strategy` | `strategy_loader` | Controls parallelism model |
| `callback` | `callback_loader` | Output formatting, event handling |
| `lookup` | `lookup_loader` | Data sourcing for loops |
| `filter` | `filter_loader` | Jinja2 filters |
| `vars` | `vars_loader` | Dynamic variable sources |
| `cache` | `cache_loader` | Fact caching backends |
| `inventory` | `inventory_loader` | Inventory source parsing |
| `shell` | `shell_loader` | Shell-specific command quoting |
| `vars_plugin` | `vars_plugin_loader` | VARS plugin sources (ocP dynamic inventory etc) |

**Plugin loading (`plugins/loader.py`):**  
`PluginLoader` handles discovery, caching, and instantiation. Searches: built-in paths, `ANSIBLE_*_PLUGINS` env vars, collection plugin directories. Supports **Collections framework** (`ansible.builtin.*`, `ansible.legacy.*` namespaces) with FQCN resolution.

**Action plugin system (`plugins/action/`):**  
- `ActionBase` abstract class; key method: `run(tmp, task_vars) → dict`  
- Behavioral flags: `BYPASS_HOST_LOOP`, `TRANSFERS_FILES`, `_requires_connection`, `_supports_check_mode`  
- Built-in actions: `normal.py` (default), `command.py`, `shell.py`, `copy.py`, `template.py`, `gather_facts.py`, etc.  
- `normal.py` action: transfers module to remote, executes via connection

**Connection plugins (`plugins/connection/`):**  
- `ConnectionBase` has abstract methods: `_connect()`, `exec_command()`, `put_file()`, `fetch_file()`  
- SSH plugin wraps system `ssh`/`scp`/`sftp` with ControlPersist, SSH agent, `sshpass` support  
- Other connections: `local.py`, `psrp.py`, `winrm.py`

---

## 3. What Ansible Has That Configr Doesn't

### 3.1 Multi-Host Fundamentals

| Feature | Ansible | configr |
|---------|---------|---------|
| **Inventory / target registry** | `InventoryManager` + `InventoryData` + `Host`/`Group` objects | ❌ None. Single `ExecutionService` per run |
| **Host pattern matching** | Shell globs, ranges, intersection, exclusion, ordering | ❌ None |
| **Group targeting** | Hierarchical groups with parent/child relationships | ❌ None |
| **Host variables / per-host overrides** | `host_vars/`, `group_vars/`, precedence-ordered variable layering | ❌ None |
| **Parallel execution** | Multi-process fork pool, pluggable strategies | ❌ Sequential only |
| **Strategy plugins (linear/free)** | Lockstep vs. independent host execution | ❌ None |
| **Serialized batches** | `serial: 1`, `50%`, `[1,5,10]` progressive | ❌ None |
| **Delegation (`delegate_to`)** | Execute task on different host, return facts to original | ❌ None |
| **Dynamic inventory** | Runtime host/group addition, inventory refresh | ❌ None |

### 3.2 Execution Control Flow

| Feature | Ansible | configr |
|---------|---------|---------|
| **Conditional execution (`when`)** | Per-task conditional evaluated before execution | ❌ None |
| **Loops (`loop`, `with_*`)** | Iterator over items, lookup plugins for data sources | ❌ None |
| **Register / `set_fact`** | Capture results, create host-specific variables | ⚠️ `set_fact` exists but is local-only, no host isolation |
| **Retry loops (`until`)** | Retry task until condition met with delay/retries | ⚠️ `retry_handler.dart` exists but is generic, not block-integrated |
| **Async & polling** | Background task execution, `async_status` polling | ❌ None |
| **Block/Rescue/Always** | Try/except/finally semantics per container | ❌ None (flat `execute`/`rollback`) |
| **Handler notifications** | `notify:` triggers handlers at flush points | ❌ None |

### 3.3 Data & Facts

| Feature | Ansible | configr |
|---------|---------|---------|
| **Automatic fact gathering** | `setup` module gathers system facts, persisted in cache | ⚠️ `gather_facts` block runs commands but results are local-only |
| **Fact caching** | Pluggable fact cache (jsonfile, memcache, redis, etc.) | ❌ None — facts reset per run |
| **Magic variables (`hostvars`)** | Lazy per-host variable templating | ❌ No cross-host variable access |
| **Jinja2 templating** | Full templating engine for all strings, conditionals, arguments | ⚠️ Simple string substitution in properties/templates |
| **DataLoader (DWIM paths)** | Role-aware, vault-aware, cached file loading | ❌ Plain text loading |

### 3.4 Modularity & Reusability

| Feature | Ansible | configr |
|---------|---------|---------|
| **Roles** | Directory-based packages with `tasks/`, `handlers/`, `vars/`, `defaults/`, `meta/` | ❌ Flat blocks only |
| **Role dependencies** | Recursive loading via `meta/main.yml` | ❌ None |
| **Dynamic includes** | `import_playbook`, `include_tasks`, `include_role` at runtime | ❌ Static i3config file only |
| **Collections namespace** | FQCN (`ansible.builtin.copy`) with library distribution | ⚠️ Plugin system exists but Dart code isolation-loading not implemented |

### 3.5 Output & Observability

| Feature | Ansible | configr |
|---------|---------|---------|
| **Verbosity levels** | `-v` to `-vvvvvv`, per-tier debug output | ⚠️ Basic verbosity flag |
| **Callback plugins** | Pluggable output formatters (JSON, YAML, TOML, JUnit, custom) | ⚠️ EventBus + basic CLI handler |
| **Fork-safe output proxying** | `Display` class routes worker output through `FinalQueue` | ❌ None |
| **Deprecation warnings** | Tracked, deduplicated, emission system | ❌ None |

---

## 4. What Configr Already Does Well

configr has several architectural strengths worth preserving:

1. **Clean transport abstraction** (`ExecutionService` interface with `LocalExecutionService` + `SSHExecutionService`) — this is architecturally sound and extensible. Ansible's connection plugins achieve the same goal but with more surface area.
2. **Rich event system** — Structured events with correlation IDs, typed subscriptions, audit logging, and sensitive-value redaction outclass Ansible's callback layer in type safety.
3. **Lockfile-based rollback** — Ansible has no equivalent rollback mechanism (it relies on idempotency). configr's `V2LockfileManager` + `ActionBlock.rollback()` is a genuine differentiator.
4. **Secrets integration** — URI-based secret resolution (`vault://`, `aws://`, `env://`, etc.) with automatic redaction is more ergonomic than Ansible's Vault encryption workflow.
5. **Wide operational coverage** — 60+ block types covering files, packages, services, users, network, firewalls, etc. Ansible's 1000+ modules are broader but configr covers the common system administration surface.
6. **Plugin system** — Lua and Dart plugin systems allow custom block types. Ansible's Python plugin system is more mature and collection-based.
7. **Dry-run preview** — `dryRun` flag enables safe preview. Ansible's `--check` mode is less comprehensive.

---

## 5. Key Architectural Patterns Configr Should Adopt

### 5.1 Inventory & Target Abstraction (HIGH PRIORITY)

**Concept:** A `Target` / `Inventory` model that represents one or more hosts, groups, and connection configs.

**How to implement:**  
- New `Target` model: `{ id, connection, vars, groups }`  
- New `Inventory` parser: supports YAML/JSON host lists with pattern matching (glob, range, exclusion)  
- Replace single `ExecutionService` singleton with a **per-target** registry  
- Add `--targets-file`, `--hosts`, `--limit` CLI flags  
- `ConfigrRuntime.apply()` iterates over targets, possibly in batches or parallel

**Ansible reference:** `lib/ansible/inventory/` (entire directory)  
**configr starting point:** `lib/src/connection_config.dart` + `lib/src/utils/execution_service.dart`

### 5.2 Variable Precedence System (HIGH PRIORITY)

**Concept:** Layered variables with strict precedence: defaults → group_vars → host_vars → play vars → set_fact → extra_vars.

**How to implement:**  
- New `VariableManager` class  
- Support `host_vars/` and `group_vars/` directory conventions  
- Magic variables: `target_hostname`, `target_group_names`, `target_hosts`, `target_hostvars["name"]`  
- `combineVars()` deep-merge with precedence ordering

**Ansible reference:** `lib/ansible/vars/manager.py` (`get_vars()` at line 157)  
**configr starting point:** `gather_facts_block.dart` + `set_fact_block.dart`

### 5.3 Strategy / Execution Model (MEDIUM-HIGH PRIORITY)

**Concept:** Pluggable execution strategies beyond sequential single-target processing.

**Minimum viable implementation:**
- **Linear strategy** (default): execute all targets in lockstep or serial batches  
- **Free strategy**: execute each target independently  
- **Host-pinned strategy**: pin targets to specific connections/workers

**How to implement:**  
- New `ExecutionStrategy` interface with `execute(targets, blocks)`  
- `LinearStrategy`: iterate targets in order, execute all blocks before next target  
- `FreeStrategy`: execute targets independently, parallelize via isolates (`worker_pool` package)  
- `SerialStrategy`: execute targets in configurable batches (`serial: 1`, `serial: 50%`)

**Ansible reference:** `lib/ansible/plugins/strategy/linear.py:98` (linear)  
`lib/ansible/plugins/strategy/free.py:58` (free)

### 5.4 Block/Rescue/Always Error Containment (MEDIUM PRIORITY)

**Concept:** Nested error handling with try/except/finally semantics.

**How to implement:**  
- Extend i3config syntax with `block { }`, `rescue { }`, `always { }` sections  
- `PlaybookIterator`-style per-target state machine tracking `TASKS` → `RESCUE` → `ALWAYS` → `COMPLETE`  
- On block failure, transition to rescue; rescue failure transitions to always; always always executes

**Ansible reference:** `lib/ansible/playbook/block.py:35`  
`lib/ansible/executor/play_iterator.py:324-425`

### 5.5 Role System (MEDIUM PRIORITY)

**Concept:** Directory-based reusable configuration packages.

**How to implement:**  
- Add `roles/` path to config lookup  
- Each role directory: `tasks/`, `handlers/`, `vars/`, `defaults/`, `meta/`, `files/`, `templates/`  
- `meta/main.yaml` declares dependencies, supported OS, tags  
- `import_role` (static) vs `include_role` (dynamic) semantics  
- Role variables have higher precedence than defaults

**Ansible reference:** `lib/ansible/playbook/role/__init__.py:114-674`  
`lib/ansible/playbook/role/definition.py:41-235`

### 5.6 Per-Task Control Flow (LOW-MEDIUM PRIORITY)

**Concept:** Conditional execution, loops, retries, delegation per block.

**How to implement:**  
- `when` — boolean expression evaluated before `execute()`  
- `loop` — iterator over items, block executes once per item  
- `register` / `set_fact` — persist result into shared variable store  
- `until` / `retries` / `delay` — retry loop around `execute()`  
- `delegate_to` — execute block on different target, variable scope routing

**Ansible reference:** `lib/ansible/executor/task_executor.py:142-655`

### 5.7 Templating Upgrade (LOW-MEDIUM PRIORITY)

**Concept:** Upgrade from simple string substitution to full Jinja2-style templating.

**How to implement:**  
- Evaluate all property strings through a template engine before `readAdditionalProperties()`  
- Custom filters: URL helpers, regex replace, json_query  
- Custom tests: `is file`, `is dir`, version comparison  
- Lookup plugins: `env`, `file`, `pipe`, `password` for data sourcing

**Ansible reference:** `lib/ansible/template/__init__.py:34-409`

---

## 6. Code Path References

### Ansible (multi-host core)

| Feature | Path | Key Classes/Functions |
|---------|------|----------------------|
| Inventory | `lib/ansible/inventory/manager.py` | `InventoryManager.get_hosts()` |
| Inventory | `lib/ansible/inventory/data.py` | `InventoryData` |
| Host | `lib/ansible/inventory/host.py` | `Host`, `VariableManager` integration |
| Group | `lib/ansible/inventory/group.py` | `Group`, parent/child hierarchy |
| Variables | `lib/ansible/vars/manager.py` | `VariableManager.get_vars()`, `_get_magic_variables()` |
| Hostvars | `lib/ansible/vars/hostvars.py` | `HostVarsVars` lazy mapping |
| Play | `lib/ansible/playbook/play.py` | `Play.compile()` |
| Task | `lib/ansible/playbook/task.py` | `Task` fields: `when`, `loop`, `register`, `delegate_to` |
| Block | `lib/ansible/playbook/block.py` | `Block`, `block/` → `rescue/` → `always/` |
| Role | `lib/ansible/playbook/role/__init__.py` | `Role`, recursive dependencies |
| Role | `lib/ansible/playbook/role/definition.py` | `RoleDefinition`, validation |
| Executor | `lib/ansible/executor/task_executor.py` | `TaskExecutor.run()`, `_get_loop_items()`, `_run_loop()` |
| Executor | `lib/ansible/executor/playbook_executor.py` | `PlaybookExecutor._get_serialized_batches()` |
| TQM | `lib/ansible/executor/task_queue_manager.py` | `TaskQueueManager` multiprocessing orchestrator |
| Iterator | `lib/ansible/executor/play_iterator.py` | `PlayIterator`, `HostState`, per-host state machine |
| Strategy | `lib/ansible/plugins/strategy/linear.py` | `StrategyModule._get_next_task_lockstep()` |
| Strategy | `lib/ansible/plugins/strategy/free.py` | `StrategyModule` independent execution |
| Strategy | `lib/ansible/plugins/strategy/host_pinned.py` | Host-to-worker affinity |
| Connection | `lib/ansible/plugins/connection/__init__.py` | `ConnectionBase` abstract interface |
| Connection | `lib/ansible/plugins/connection/ssh.py` | SSH connection, ControlPersist, multiplexing |
| Action | `lib/ansible/plugins/action/__init__.py` | `ActionBase.run()` |
| Action | `lib/ansible/plugins/action/normal.py` | Default module execution via connection |
| Template | `lib/ansible/template/__init__.py` | `Templar` class |
| DataLoader | `lib/ansible/parsing/dataloader.py` | `DataLoader`, DWIM paths, Vault decryption |
| Display | `lib/ansible/utils/display.py` | `Display` class, fork-safe output, verbosity tiers |

### Configr (single-target core)

| Feature | Path | Key Classes/Functions |
|---------|------|----------------------|
| Block execution | `lib/src/blocks/action_block.dart` | `ActionBlock.afterChildrenProcessed()`, `execute()`, `rollback()` |
| v2 apply pipeline | `lib/src/blocks/v2_apply.dart` | `applyV2()` |
| Transport | `lib/src/utils/execution_service.dart` | `ExecutionService` interface |
| SSH transport | `lib/src/utils/ssh_execution_service.dart` | `SSHExecutionService` (single host) |
| Connection | `lib/src/connection_config.dart` | `ConnectionConfig`, `ConnectionBlock` |
| DI | `lib/src/di.dart` | `get_it` registration of services |
| Events | `lib/src/utils/event_bus.dart` | `EventBus` broadcast streams |
| Lockfile | `lib/src/utils/v2_lockfile_manager.dart` | `V2LockfileManager`, drift checksum |
| Hooks | `lib/src/hooks/hook_manager.dart` | `HookManager`, Lua/script hooks |
| Facts | `lib/src/utils/system_info.dart` | Built-in system variables |
| Facts block | `lib/src/blocks/gather_facts_block.dart` | `GatherFactsBlock` |
| Retry | `lib/src/utils/retry_handler.dart` | `RetryHandler` |
| Privilege escalation | `lib/src/utils/privilege_escalation.dart` | `PrivilegeEscalation` implementations |
| Seals | `lib/src/secrets/secret_resolver.dart` | URI-based secret resolution |

---

## 7. Conclusion & Next Steps

### Strategic Gap

configr is a **single-target configuration management tool** with excellent execution abstractions and rollback support. Its biggest gap for multi-host use is the lack of an **inventory system, target abstraction, and host variable model**.

### Recommended Adoption Priority

| Priority | Feature | Effort | Impact |
|----------|---------|--------|--------|
| **P1** | Inventory & target abstraction | High | Enables all multi-host functionality |
| **P1** | Variable precedence system | Medium | Makes configs adaptive per host |
| **P2** | Strategy plugins (linear/free) | Medium | Enables parallel/batched execution |
| **P2** | Block/Rescue/Always | Medium | Improves error handling semantics |
| **P2** | Fact caching & hostvars | Medium | Enables cross-host orchestration |
| **P3** | Role system | High | Improves reusability/composition |
| **P3** | Per-task control flow (`when`, `loop`, `until`) | Medium | Makes blocks more declarative |
| **P3** | Templating upgrade (Jinja2) | High | Makes configs more dynamic |

### Quick Wins (Low effort, immediate value)

1. **Host targeting CLI flags** — Add `--host`, `--hosts-file`, `--limit-host` flags that wrap the existing `ConnectionBlock` mechanism. This immediately enables multi-host via external orchestration without changing the core engine.
2. **Expanded `set_fact`** — Upgrade `set_fact_block.dart` to store in a **global fact cache** (file-backed) rather than per-run context. Enables basic cross-run host-aware configs.
3. **Serial flag** — Add `serial: 1` and `serial: N` support in config. Implement as a simple loop over targets with same config applied each time.
4. **Verbosity/callback tiers** — Expand the `EventBus` + `CLIHandler` to support verbosity levels (`-v` to `-vvvv`) and output format plugins (JSON, YAML).

### Non-Goals

- **Do not copy Ansible's module library** — configr's 60+ blocks already cover the common system admin surface.  
- **Do not adopt Ansible's INI inventory format** — YAML/JSON is more consistent with configr's existing config formats.  
- **Do not replace the i3config syntax** — It is a differentiator. Extend it with `target { }` and `when` rather than switching to YAML playbooks.
