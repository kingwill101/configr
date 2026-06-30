# Additional Features Research: Beyond Core Architecture

## Purpose

This document captures patterns from Kamal and Ansible that were not covered in the primary architecture deep-dives, with emphasis on features configr can adopt with minimal disruption to its i3config syntax and Dart codebase.

---

## 1. Kamal: Proxy & Server Commands

### Source Files
- `kamal/lib/kamal/commands/proxy.rb` (146 lines)
- `kamal/lib/kamal/commands/server.rb` (15 lines)

### Key Patterns

**Proxy as bootable component**
- Kamal treats the proxy (Traefik) as a separate, versioned boot component
- Proxy reads its own config from files on disk: boot options, image, image version, run command
- `Proxy::Boot` reads files with fallback defaults (`read_file` combines `cat` with `|| echo default`)
- Proxy has its own lifecycle: `run`, `start`, `stop`, `remove_container`, `remove_image`, `cleanup_traefik`
- Proxy boot config written to `kamal-proxy-config` docker volume plus host directory

**Proxy run configuration per host**
- `config.proxy_run(host)` returns the run config for a specific host
- Validates that all proxy run configs are identical across hosts to prevent conflicts
- `proxy_runs(host)` collects proxy configs from both roles and accessories on that host

**Server command minimalism**
- `Kamal::Commands::Server` is a thin wrapper: ensure run directory, count apps, remove app directory
- Focuses on directory management and counting, not complex orchestration

**Relevance to configr**
- configr could adopt a similar "boot loader" pattern for handling bootstrap/init scripts before main config execution
- The `read_file with default` pattern (`cat file 2>/dev/null || echo default`) is a useful shell idiom for optional config values
- Proxy's per-host validation of identical configs maps to configr's `connectionConfig` host validation

---

## 2. Kamal: Secrets CLI

### Source Files
- `kamal/lib/kamal/cli/secrets.rb` (referenced in AGENTS.md, not found in third_party at expected path)

### Key Patterns (from main research)

**Secrets as first-class config object**
- `Kamal::Secrets` is instantiated during `Configuration` initialization
- Secrets path defaults to `.kamal/secrets` but is configurable
- Secrets are loaded early and passed to `Registry`, `Env`, `Proxy` configs
- Secrets integrate with ERB templating in config files (`<%= ENV["SECRET_NAME"] %>`)

**Secrets CLI commands**
- `kamal secrets fetch` — pulls secrets from remote (e.g., AWS SSM, environment)
- `kamal secrets set` — writes a single secret
- `kamal secrets show` — displays secrets (with redaction)
- `kamal secrets remove` — deletes a secret

**Integration pattern**
- Secrets are resolved at config load time, not at execution time
- The `secrets_path` is a configurable file path supporting different secret backends

**Relevance to configr**
- configr already has `SecretsBlock` for URI-based secret resolution during block processing
- Could adopt Kamal's "load secrets before config" pattern by exposing secret values as i3config variables
- A `configr secrets` CLI subcommand could manage `.configr/secrets/` without altering core block pipeline

---

## 3. Ansible: Callback Plugin System

### Source Files
- `ansible/lib/ansible/plugins/callback/__init__.py` (777 lines)

### Key Patterns

**Event-driven plugin architecture**
- `CallbackBase` defines lifecycle hooks for every execution event
- v2 methods: `v2_runner_on_failed`, `v2_runner_on_ok`, `v2_runner_on_skipped`, `v2_playbook_on_start`, `v2_on_any`, etc.
- v1 backward-compatibility layer with `_v2_v1_method_map` for gradual migration

**Optimization: method introspection**
- `_init_callback_methods()` inspects which methods a subclass overrides via `inspect.ismethod`
- Stores `_implemented_callback_methods` as a frozenset for fast dispatch bypass
- Deprecates v1 method overrides with version-targeted warnings

**Result formatting**
- `_dump_results()` handles JSON/YAML output with configurable format, indentation, width
- `_get_diff()` renders unified diffs with color support
- Result filtering strips internal `_ansible_*` keys from display output

**Event taxonomy**
- Task-level: `v2_runner_on_*` (failed, ok, skipped, unreachable)
- Play-level: `v2_playbook_on_*` (start, stats, notify, no_hosts)
- Item-level (loops): `v2_runner_item_on_ok`, `v2_runner_item_on_failed`
- Async: `v2_runner_on_async_poll`, `v2_runner_on_async_ok`, `v2_runner_on_async_failed`
- Retry: `v2_runner_retry`

**Relevance to configr**
- configr's `EventBus` already emits `StatusUpdateEvent` with level/message/moduleId/metadata
- The callback pattern maps directly: each `ActionBlock` could emit events at `pre_execute`, `post_execute`, `on_rollback`, `on_error`
- `_implemented_callback_methods` introspection is overkill for configr, but the event taxonomy aligns with configr's `BlockErrorRecord`
- Result formatting with JSON/YAML toggle is useful for `configr status --format json`

---

## 4. Ansible: DataLoader & Vault Integration

### Source Files
- `ansible/lib/ansible/parsing/dataloader.py` (508 lines)

### Key Patterns

**File caching layer**
- `_FILE_CACHE` dict prevents rereading unchanged files
- Options: `cache='none'`, `cache='all'`, `cache='vaulted'`
- Vault-encrypted files cached separately from plaintext

**Path resolution (path_dwim)**
- `path_dwim()` — "do what I mean" path resolution for relative/absolute paths
- `path_dwim_relative()` and `path_dwim_relative_stack()` for role/playbook-relative lookups
- Handles home directories (`~`), absolute paths, and relative paths from basedir

**Vault decryption pipeline**
- `_decrypt_if_vault_data()` checks if bytes are encrypted, decrypts if so
- `get_text_file_contents()` returns Origin-tagged strings with encoding fallback
- `get_real_file()` returns path to temp decrypted file, cleans up in destructor
- `_create_content_tempfile()` for transient decrypted content

**find_vars_files**
- Recursively searches directories for vars files by name
- Supports extensions list and hidden/backup file exclusion
- Returns ordered list of candidate files

**Relevance to configr**
- configr's `SecretsBlock` already resolves URIs to secrets at block execution time
- Could adopt DataLoader's caching pattern for template rendering: cache resolved templates keyed by source+checksum
- `path_dwim` pattern is partially implemented in `_ConfigrFileSystem.readFile()` for config includes; could be extended for block-level file resolution
- Vault's temp-file-with-cleanup pattern could inform how configr passes decrypted secrets to subprocesses without lingering plaintext

---

## 5. Configr: Current Implementation Cross-Reference

### HookManager (`hook_manager.dart`, 111 lines)
- Events: `pre-apply`, `post-apply`, `pre-block`, `post-block`, `pre-connect`, `on-error`
- Supports Lua and shell hooks via `_runLuaHook` and `_runShellHook`
- Environment variable injection (`CONFIGR_EVENT`, `CONFIGR_${KEY}`)
- Missing: Kamal-style per-hook output control (`quiet` vs `verbose`)

### RetryHandler (`retry_handler.dart`, 274 lines)
- Exponential backoff with jitter (±25%)
- ErrorCategory-based retry decisions
- Preset configs: `network`, `fileOperation`, `commandExecution`
- Parallel and sequential execution modes
- Missing: Kamal-style retry count per-block rather than global

### AuditLogger (`audit_logger.dart`, 646 lines)
- Singleton pattern with EventBus integration
- Log levels: trace, debug, info, warning, error, critical
- File rotation with max size/max files/compression
- Context merging for metadata
- Auto-flush at 1000 entries
- Missing: structured JSON output compatible with Ansible callback `_dump_results`

### V2LockfileManager (`v2_lockfile_manager.dart`, 55 lines)
- Simple JSON lockfile at `<config>.lock.json`
- Written after successful apply, read during rollback
- Consolidated into `v2_apply.dart`'s orchestration
- Missing: Kamal-style mkdir-based distributed lock for multi-host coordination

### EventBus (`event_bus.dart`, referenced)
- `StatusUpdateEvent` with level, message, moduleId, metadata
- Already integrated with AuditLogger
- Could be extended with the full Ansible callback event taxonomy

---

## 6. Feature Gap Analysis

### Already Implemented (configr)
| Feature | Status |
|---------|--------|
| Hooks (pre/post) | `HookManager` with Lua + shell support |
| Retry with backoff | `RetryHandler` with category-based logic |
| Audit logging | `AuditLogger` singleton with file rotation |
| Lockfile tracking | `V2LockfileManager` for rollback |
| Event bus | `EventBus` with `StatusUpdateEvent` |
| Secret resolution | `SecretsBlock` with URI scheme dispatch |
| SSH transport | `SSHExecutionService` for remote hosts |

### High-Value / Low-Effort Additions
| Feature | Source | Effort | Justification |
|---------|--------|--------|---------------|
| Pre/post-apply scripts | Kamal | Low | Already in `v2_apply.dart`; could be i3config-native |
| Config merging by destination | Kamal | Low | Deep-merge `.base.yml` with `.dest.yml` for multi-env |
| Hook output control | Kamal | Low | Add `hooks_output: quiet/verbose` to `.configr/config` |
| Docs-as-schema validation | Kamal | Medium | Validate i3config against inline examples before processing |
| JSON status output | Ansible | Low | Add `--format json` to `configr status` |

### Medium-Value / Medium-Effort
| Feature | Source | Effort | Justification |
|---------|--------|--------|---------------|
| mkdir-based distributed locks | Kamal | Medium | Enable multi-host apply without SSH-based coordination |
| Block-level retry config | Kamal/Rust | Medium | Per-block `retries = N` instead of global |
| Callback event taxonomy | Ansible | Medium | Standardize event names across audit + UI |
| Vault-style secret loading | Ansible | Medium | Decrypt secrets at load time, cache ciphertext |

### High-Value / High-Effort
| Feature | Source | Effort | Justification |
|---------|--------|--------|---------------|
| Multi-host inventory | Kamal | High | `target { host, role }` blocks with serial boot groups |
| Strategy plugins | Ansible | High | Linear (per-host sequential) vs free (parallel) execution |
| Facts gathering | Ansible | High | `gather_facts` → `set_fact` variable framework |
| Host variables | Ansible | High | `hostvars` access for cross-host templating |

---

## 7. Recommended Next Steps

1. **Lockfile enhancement**: Extend `V2LockfileLockfileData` to include `executionStrategy` field for future serial/parallel support (Kamal influence)
2. **Hook manager**: Add `_hookOutputLevel` with per-hook or global `quiet`/`verbose` setting (Kamal influence)
3. **Event taxonomy**: Create `configr_event_taxonomy.md` mapping Ansible callback events to configr `EventBus` events
4. **Secrets CLI**: Design `configr secrets fetch/set/show` subcommands (Kamal influence)
5. **Status format**: Add `--output json|text` to status/diff commands (Ansible callback formatting)

---

## 8. Coding Patterns to Adopt

### Kamal's `load_config_file` pattern (ERB + YAML)
Kamal renders ERB before YAML parse, enabling dynamic values in config:
```ruby
template = File.read(file)
rendered = ERB.new(template, trim_mode: "-").result
YAML.unsafe_load(rendered)
```
configr applies i3config parsing which has its own variable system; keeping separate.

### Kamal's `destination_config_file` pattern
```ruby
def destination_config_file(base, destination)
  base.sub_ext(".#{destination}.yml") if destination
end
```
configr could use this pattern for per-host overrides: `configr.hostname` → `configr.host-specific.i3config`.

### Ansible's `DataLoader` caching pattern
```python
if cache != 'none' and file_name in self._FILE_CACHE:
    return self._FILE_CACHE[file_name]
```
configr could cache resolved `template_block` outputs to avoid re-rendering unchanged templates.

### Ansible's `_decrypt_if_vault_data` pattern
```python
if encrypted_source := is_encrypted(b_data):
    b_data = self._vault.decrypt(b_data)
```
configr's `SecretsBlock` could detect encrypted content automatically rather than requiring explicit URI schemes.

---

*Generated from deep-dive into Kamal `proxy.rb`, `server.rb`, `configuration.rb`, and Ansible `callback/__init__.py`, `parsing/dataloader.py`, cross-referenced with configr's `v2_apply.dart`, `hook_manager.dart`, `retry_handler.dart`, `audit_logger.dart`, `v2_lockfile_manager.dart`.*
