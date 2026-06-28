# Multi-Host Testing Research

## Source of truth for reliable, scalable multi-host test strategy

---

## 1. Kamal's multi-host testing architecture (reference implementation)

### 1.1 Test layers

Kamal uses **two distinct test layers** for multi-host behavior:

| Layer | Directory | Runner | What it tests | Speed |
|-------|-----------|--------|---------------|-------|
| Unit | `test/configuration/`, `test/commands/` | `rails test` | Config parsing, role/group merging, boot limits, strategy selection, secret adapters, lock behavior | Fast (~seconds) |
| Integration | `test/integration/` | `rails test` with Docker Compose | Full deploy lifecycle against real containers: boot, hooks, proxy, secrets, rollback, drift, concurrent deploy prevention | Slow (~minutes) |

Key file: `third_party/kamal/test/integration/integration_test.rb`
- Brings up a full Docker Compose stack (deployer, vm1, vm2, shared, load_balancer, registry, proxy)
- Uses stable per-worktree project names (`kamal-test-<sha>`) so parallel CI jobs don't collide
- Discovers ephemeral published ports at runtime
- Runs `kamal deploy`, `kamal rollback`, `kamal proxy`, etc. against the real binary inside the deployer container
- Asserts HTTP-level behavior (200/502/503) and hook side effects
- Tears down with `docker compose down -t 0`

### 1.2 What Kamal unit-tests for multi-host

Kamal has dedicated unit test files under `test/configuration/`:

| File | What it covers |
|------|----------------|
| `test/configuration/role_test.rb` (341 lines) | Host listing per role, `cmd` override, `env` merge/override, label args, custom labels, secrets I/O per role |
| `test/configuration/boot_test.rb` (49 lines) | Boot limit (int and `%`), boot wait, `parallel_roles`, minimum 1 host for percentage |
| `test/configuration/env_test.rb` | Per-role env file generation |
| `test/configuration/env/tags_test.rb` | Tag-filtered env values |
| `test/configuration/ssh_test.rb` | SSHKit integration |
| `test/configuration/validation_test.rb` | Config schema validation |

It also has CLI-level unit tests under `test/cli/`:

| File | What it covers |
|------|----------------|
| `test/cli/server_test.rb` | Server display, role filtering |
| `test/cli/lock_test.rb` | Lock acquire/release via CLI |
| `test/cli/proxy_test.rb` | Proxy boot/run config |

### 1.3 What Kamal integration-tests for multi-host

| File | What it covers |
|------|----------------|
| `test/integration/main_test.rb` | Full deploy → verify → rollback → re-deploy cycle across multiple VMs |
| `test/integration/lock_test.rb` | Concurrent deploy prevention |
| `test/integration/proxy_test.rb` | Proxy boot/role ordering across hosts |

### 1.4 Kamal fixture strategy

Kamal uses **YAML fixtures** as the canonical source of test configs:

- `test/fixtures/deploy_with_roles.yml` — multi-role, per-role overrides
- `test/fixtures/deploy_with_boot_strategy.yml` — boot.limit, boot.wait
- `test/fixtures/deploy_with_parallel_roles.yml` — explicit parallel groups
- `test/fixtures/deploy_with_proxy_roles.yml` — proxy-only role
- `test/fixtures/deploy_with_multiple_proxy_roles.yml` — overlapping proxy/non-proxy

Each fixture is a complete, minimal YAML document that exercises one behavior. Tests instantiate `Kamal::Configuration.new(YAML.load_file(...))` and assert on the resulting object graph.

### 1.5 Key testing patterns from Kamal

1. **Config-as-fixture**: Minimal config files, one behavior per file
2. **Object-level assertions**: Unit tests assert on the parsed configuration model, not process exit codes
3. **CLI harness**: `CliTestCase` subclasses run the real binary, capture stdout/stderr, assert on output content
4. **Integration via Compose**: Full system tests use Docker; deterministic teardown; logs on failure
5. **Idempotency baked in**: Every config scenario is applied twice in the sweep test
6. **Output contract**: `args`, `out_contains`, `out_not_contains` files define the test contract declaratively

---

## 2. Configr's current testing landscape

### 2.1 What exists

**Sweep harness** — `test/integration/sweep_test.dart`:
- Iterates every directory in `test/integration/configs/`
- Runs `configr apply --v2 --config <path> -n` (dry-run) twice
- Runs `setup.sh` before, `verify.sh` after, `cleanup.sh` in tearDown
- Supports `tags`, `args`, `out_contains`, `out_not_contains`
- Gated on `CONFIGR_TEST_ENV=linux`

**Unit tests for multi-host** — `test/multi_host/` (21 files, 2,630 lines):
- Host, Role, Inventory, TargetResolver, BootGroup, DriftDetector, HostLock, HostVars, HostEvents, HostExecutionContext
- Strategies: Linear, Serial, Parallel, StrategyResolver
- Infrastructure: ConnectionPool, HostApplier, HostRollback
- Behavior: VariablePrecedence
- CLI: RollbackCli

**Sensitive variable tests** — `test/secrets/sensitive_variable_middleware_test.dart` (12 tests)

**Multi-host integration scenarios** currently in `test/integration/configs/`:
- `multi_host_inventory_test` — targets specific hosts via `--target`
- `dependency_test` — minimal network check

### 2.2 What's missing

| Coverage area | Configr | Kamal equivalent |
|--------------|---------|------------------|
| Multi-host strategy execution (linear/serial/parallel) | Unit only | Integration (Compose) + CLI unit |
| Boot group / boot limit | Unit only | Unit + Integration |
| Role + group var precedence | Unit only | Unit + Integration |
| delegate_to forwarding | Unit only | Unit only |
| Rollback after partial failure | Unit only | Integration |
| Drift detection end-to-end | Unit only | Integration |
| Host concurrency lock | Unit only | Integration |
| Sensitive redaction in real CLI output | Integration exists | Not shown |
| `hosts`, `status --host`, `diff --target` CLI | ❌ missing | CLI unit tests |
| Rollback CLI (`rollback --host`) | Unit | CLI unit |

### 2.3 Gap analysis

The biggest gap is **integration-level validation of multi-host flows**. Configr has:
- ✅ Solid unit foundation (every model and strategy has unit tests)
- ✅ Sensitive middleware tested in isolation
- ❌ No end-to-end multi-host integration test that exercises inventory → strategy → execution → lockfile → rollback in one flow
- ❌ No Docker/container SSH-based integration test (everything is local dry-run or mocked SSH)
- ❌ No CLI-level tests for the new multi-host commands

---

## 3. Proposed test strategy for configr

### 3.1 Design principles (borrowed from Kamal)

1. **Two layers**: Unit tests for models/strategies; integration tests for full flows
2. **Local first**: Use the existing `sweep_test.dart` pattern for local integration (no Docker required, just set `CONFIGR_TEST_ENV=linux`)
3. **SSH second**: Add a Docker-based integration harness that runs real SSH against containerized hosts
4. **One behavior per fixture**: Each `test/integration/configs/<name>/` directory tests one specific multi-host feature
5. **Declarative contracts**: Use `args`, `out_contains`, `out_not_contains` files
6. **Idempotency always**: Sweep runs every scenario twice
7. **Clean teardown**: Every scenario has `cleanup.sh`

### 3.2 Phase 1 — Local sweep scenarios (highest leverage)

Add new directories under `test/integration/configs/` (each with `config`, `verify.sh`, `cleanup.sh`, `args`):

| Scenario | Tests | args | verify.sh checks |
|----------|-------|------|-------------------|
| `multi_host_strategy_linear` | Ordered execution, one host at a time | `--strategy linear --target web-01 --target web-02 --target db-01` | Output contains `/web-01/` then `/web-02/` then `/db-01/` |
| `multi_host_strategy_parallel` | All hosts run concurrently | `--strategy parallel --target web-01 --target web-02 --target db-01` | Output contains all three host markers (order not guaranteed) |
| `multi_host_strategy_serial` | Boot-group ordering | `--strategy serial --target web-01 --target db-01` with boot groups | Output respects group ordering |
| `multi_host_hostvars` | Per-host variable precedence | `--target web-01 --target web-02` with host vars | `echo` block prints host-specific value |
| `multi_host_groupvars` | Group-level variable fallback | `--target web-01 --target db-01` with group vars | `echo` block prints group value for hosts without host override |
| `multi_host_precedence` | `--var` > host vars > group vars > secrets > facts | `--var "override=cli" --target web-01` | `echo` prints `cli` when all layers define the same key |
| `multi_host_delegate` | `delegate_to` forwarding | `--target proxy-01` with delegate_to block | Output shows delegated host marker |
| `multi_host_drift` | Drift detection across hosts | Two applies with modified config | Second apply reports drift |
| `multi_host_rollback` | Per-host rollback | Apply, then `rollback --host web-01` | Lockfile for web-01 removed, state restored |
| `multi_host_lock` | Host lock prevents double execution | Rapid double apply | Second apply fails with lock error |

Each scenario uses `tags: linux` so it runs under `CONFIGR_TEST_ENV=linux`.

### 3.3 Phase 2 — Docker-based SSH integration tests

Kamal's integration tests spin up a Docker Compose stack with multiple VMs and run the real binary against them. Configr can mirror this:

**Required infrastructure:**
1. `test/integration/docker/docker-compose.yml` — defines:
   - `deployer` — container with configr binary and SSH key
   - `vm1`, `vm2`, `vm3` — lightweight SSH servers (e.g., `lscr.io/linuxserver/openssh-server`)
   - Shared volume for test artifacts
   - Network bridge
2. `test/integration/docker/boot.sh` — starts SSH daemons, injects test keys, creates test users
3. `test/integration/docker/integration_test.dart` — Dart equivalent of Kamal's `integration_test.rb`:
   - Brings up Compose
   - Waits for health checks
   - Runs `configr apply` with inventory pointing to containers
   - Verifies via SSH (check files, services)
   - Tests rollback, drift, strategy ordering
   - Tears down Compose

**What this unlocks:**
- Real SSH connection pooling
- Real `host_applier` remote execution
- Real per-host lockfiles on actual filesystems
- Real config file uploads and remote configr execution
- True multi-host dependency checks (host A must be reachable before host B runs)

### 3.4 Phase 3 — CLI command tests

Add `test/multi_host/cli_test.dart` to exercise the new CLI subcommands:

| Command | What to test |
|---------|-------------|
| `configr hosts` | Lists inventory hosts, roles, groups |
| `configr hosts --role web` | Filters by role |
| `configr status --host web-01` | Shows host details + lockfile status |
| `configr status --host web-01` (no inventory) | Shows error message |
| `configr diff --target web-01 --target db-01` | Shows per-target diff |
| `configr diff` (no target) | Falls back to single-host diff |
| `configr rollback --host web-01` | Rolls back single host |
| `configr rollback --host web-01 --host web-02` | Rolls back multiple hosts |

Pattern: Use `ConfigrCommandRunner` directly (like the sweep test does), capture stdout/stderr, assert on output content.

### 3.5 Phase 4 — Gap-filling unit tests

Small additions to existing files:

| File | New tests |
|------|-----------|
| `boot_group_test.dart` | Empty host list, timeout behavior, equal group sizes |
| `host_lock_test.dart` | Contention (two callers, one wins), releaseAll idempotent |
| `host_applier_test.dart` | Host vars forwarded as `--var`, extraApplyArgs forwarded |
| `dependency_checker_test.dart` | Network vs ping check, timeout, cycle detection (new) |

---

## 4. Existing integration scenarios inventory

Current `test/integration/configs/` contents (66 directories):

```
alternatives_absent, alternatives_editor, assert_test, authorized_key_test,
backup_test, blockinfile_test, compress_test, connection_test, copy_test,
cron_create, cron_disabled, cron_remove, cron_test, debug_msg,
decompress_test, delete_test, dependency_test, echo_test, execute_test,
fetch_file, file_create, firewalld_test, gather_facts, group_create,
group_remove, hostname_set, known_hosts_test, lineinfile_test,
locale_gen_en_us, locale_gen_multi, mount_test, move_test,
multi_host_inventory_test, network_test, pause_test, permissions_test,
raw_uptime, rename_test, replace_test, script_run, secrets_cmd_test,
secrets_dotenv_test, secrets_file_test, secrets_redaction_test,
service_test, set_fact, slurp_file, stat_directory, stat_file,
symlink_test, sync_test, sysctl_remove, sysctl_set, systemd_test,
template_test, timezone_set_ny, timezone_set_utc, touch_test, ufw_test,
unarchive_tar, uri_get, user_create, user_modify, user_remove,
validate_test, wait_for_test
```

Only **one** is multi-host (`multi_host_inventory_test`). The rest are single-host block tests.

---

## 5. Decision log

| Decision | Rationale | Date |
|----------|-----------|------|
| Adopt Kamal's two-layer test model (unit + integration) | Proven pattern for multi-host config management; unit tests catch logic bugs fast, integration catches wiring bugs | 2025-06-28 |
| Reuse `sweep_test.dart` for local multi-host integration | Zero new infrastructure; leverages existing `setup.sh`/`verify.sh`/`cleanup.sh` pattern; runs under `CONFIGR_TEST_ENV=linux` | 2025-06-28 |
| Add Docker-based SSH integration as Phase 2, not Phase 1 | Docker Compose harness is heavier; local sweep gives 80% of the value with 20% of the effort | 2025-06-28 |
| Use declarative `args`/`out_contains`/`out_not_contains` files | Consistent with existing sweep_harness; human-readable test contracts | 2025-06-28 |
| Add CLI command tests in `test/multi_host/cli_test.dart` | Mirrors Kamal's `test/cli/` layer; tests the public surface users interact with | 2025-06-28 |
| Keep all multi-host sweep scenarios tagged `linux` | Matches existing convention; CI can run local sweep on every PR | 2025-06-28 |

---

## 6. Open questions

1. **Docker Compose topology**: How many VMs? Kamal uses vm1 + vm2 + shared + load_balancer. Configr needs at least 3 hosts (web, db, worker) to test strategy ordering. Should we reuse Kamal's `docker/` directory or create our own?
2. **SSH key management**: How do we inject test SSH keys into containers? Kamal uses `setup.sh` scripts. Should configr follow the same pattern?
3. **Test timeout budget**: The sweep test uses `Timeout(Duration(minutes: 2))`. Docker integration tests will need 5-10 minutes per scenario. Is that acceptable for CI?
4. **Race condition testing**: Kamal's lock test verifies only one deploy runs. Should configr's `HostLock` be tested with actual concurrent processes, or is the unit-level contention test sufficient?

---

## 7. References

- `third_party/kamal/test/integration/integration_test.rb` — full Docker-based integration harness
- `third_party/kamal/test/configuration/role_test.rb` — role/group/env fixture pattern
- `third_party/kamal/test/configuration/boot_test.rb` — boot strategy unit test pattern
- `test/integration/sweep_test.dart` — configr's local sweep harness
- `lib/src/blocks/v2_apply.dart` — applyV2 entry point
- `lib/src/multi_host/` — all multi-host models, strategies, and infrastructure
