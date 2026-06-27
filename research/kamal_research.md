# Research: Kamal Architecture vs Configr
**Date:** 2026-06-27  
**Scope:** Deep dive into Kamal's multi-host deployment architecture, execution model, and key design patterns. Competitive comparison with configr, focusing on gaps and opportunities.

---

## 1. Executive Summary

**Kamal** (Ruby/Thor, ~8k LOC) is an agentless Docker deployment tool targeting multiple servers via SSHKit.  
**configr** (Dart, ~15k LOC) is a single-host configuration management tool with rollback support using an i3config-inspired declarative syntax.

**The fundamental difference:**  
- Kamal operates on **N hosts across roles** in a single run using SSHKit's parallel execution model, serialized boot groups, and a lock-based concurrency guard.  
- configr operates on **1 host** per invocation. It supports SSH transport but has no inventory, grouping, host abstraction, or target iteration. Multi-host management requires external orchestration (shell loops, scripts).

**Key takeaway:** configr's execution abstractions (`ActionBlock` + `ExecutionService`) are architecturally sound and extensible. The missing layer is **multi-target coordination**: inventory, host variables, facts, strategies, and per-host execution loops. Kamal demonstrates that these concerns can be layered cleanly on top of an SSH transport backend.

---

## 2. How Kamal Handles Multiple Hosts

### 2.1 Commander Singleton

**Implementation:** `lib/kamal/commander.rb` + `lib/kamal/cli.rb`

Kamal uses a global singleton `KAMAL = Kamal::Commander.new` as the runtime configuration hub. The Commander:

- Lazy-loads `Kamal::Configuration` from config file + destination
- Holds filter state: `specific_hosts`, `specific_roles`
- Delegates host/role queries to `Kamal::Commander::Specifics`
- Creates command objects: `KAMAL.app(role:, host:)`, `KAMAL.builder`, `KAMAL.docker`, `KAMAL.hook`, `KAMAL.lock`, `KAMAL.proxy(host)`, `KAMAL.registry`, `KAMAL.auditor`
- Resolves aliases via `KAMAL.resolve_alias(name)`
- Manages SSHKit configuration (verbosity, pool timeouts, max concurrent starts, DNS retries)
- Configures output logging (FileLogger, OTelLogger) via `ActiveSupport::BroadcastLogger`

```ruby
# lib/kamal/cli.rb
KAMAL = Kamal::Commander.new
```

### 2.2 Configuration Model (YAML + ERB + Destination Merge)

**Implementation:** `lib/kamal/configuration.rb`

Configuration is loaded from `config/deploy.yml` with optional destination overlays:

```ruby
# config/deploy.yml (base)
service: myapp
image: my-image
registry: ...
servers: ...

# config/deploy.staging.yml (overlay)
registry:
  server: staging-registry.example.com
```

**Loading sequence (`Configuration.load_raw_config`):**
1. Load base YAML file (ERB-processed via `ERB.new(template, trim_mode: "-").result`)
2. If destination provided, load `config/deploy.#{destination}.yml`
3. Deep-merge overlays: `config.deep_merge! load_config_file(file)`

**Configuration object graph:**
- `Configuration#servers` → `Servers` → array of `Role` objects
- `Configuration#roles` → delegated from `servers`
- `Configuration#accessories` → array of `Accessory` objects (db, redis, search)
- `Configuration#aliases` → map of `Alias` objects
- `Configuration#boot` → `Boot` (limit, wait, parallel_roles)
- `Configuration#builder` → `Builder` (local/remote/hybrid/cloud/pack)
- `Configuration#env` → `Env` (clear vars + secret keys + tags)
- `Configuration#proxy` → `Proxy` + `Proxy::Boot` + `Proxy::Run`
- `Configuration#ssh` → `Ssh` (user, port, keys, proxy, config)
- `Configuration#sshkit` → `Sshkit` (pool settings, DNS retries)
- `Configuration#logging` → `Logging`
- `Configuration#output` → `Output` (file/otel loggers)
- `Configuration#registry` → `Registry`

### 2.3 Role-Based Server Grouping

**Implementation:** `lib/kamal/configuration/role.rb`

Roles are the primary host grouping mechanism:

```yaml
servers:
  web:
    hosts:
      - web1.example.com
      - web2.example.com
    env:
      clear:
        RAILS_ENV: production
  workers:
    hosts:
      - worker1.example.com
    cmd: bin/jobs
```

**Role class (`Kamal::Configuration::Role`):**
- Has `name`, `hosts`, `specialized_env`, `specialized_logging`, `specialized_proxy`
- Hosts can be **tagged**: `web2.example.com: experiments,three`
- `tagged_hosts` returns a hash of `{ hostname => [tags] }`
- `env(host)` merges: `config.env` → `specialized_env` → `env_tags(host)` → reduce(:merge)
- `secrets_path` scoped per role: `.kamal/env/roles/#{name}.env`
- `running_proxy?` / `ssl?` per role
- Validated against `lib/kamal/configuration/docs/role.yml`

### 2.4 Host Filtering & Selection

**Implementation:** `lib/kamal/utils.rb` (`filter_specific_items`)

CLI filters use shell glob wildcards:

```ruby
# lib/kamal/cli/base.rb
commander.specific_hosts = options[:hosts]&.split(",")
commander.specific_roles = options[:roles]&.split(",")

# lib/kamal/utils.rb
def filter_specific_items(filters, items)
  Array(filters).select do |filter|
    matches += Array(items).select do |item|
      File.fnmatch(filter, item.to_s, File::FNM_EXTGLOB)
    end
  end
  matches.uniq
end
```

- `--hosts "web*.example.com"` matches by glob
- `--roles "web,workers"` matches role names with wildcard support
- `--primary` / `-p` restricts to primary host only

### 2.5 Serialized Boot Groups (Gradual Rollout)

**Implementation:** `lib/kamal/configuration/boot.rb` + `lib/kamal/cli/app.rb` (`host_boot_groups`)

```yaml
boot:
  limit: 1        # or "50%" or 2
  wait: 5         # seconds between groups
  parallel_roles: false
```

```ruby
# lib/kamal/cli/app.rb
def host_boot_groups
  KAMAL.config.boot.limit ? KAMAL.app_hosts.each_slice(KAMAL.config.boot.limit).to_a : [ KAMAL.app_hosts ]
end
```

```ruby
# lib/kamal/cli/app.rb: boot method
host_boot_groups.each do |hosts|
  host_list = Array(hosts).join(",")
  run_hook "pre-app-boot", hosts: host_list

  on_roles(KAMAL.roles, hosts: hosts, parallel: KAMAL.config.boot.parallel_roles) do |host, role|
    Kamal::Cli::App::Boot.new(host, role, self, version, barrier).run
  end

  run_hook "post-app-boot", hosts: host_list
  sleep KAMAL.config.boot.wait if KAMAL.config.boot.wait
end
```

This enables **rolling deployments**: deploy to 1 host at a time, wait between groups, run pre/post hooks per group.

### 2.6 SSHKit-Based Parallel Execution

**Implementation:** `lib/kamal/sshkit_with_ext.rb`

Kamal builds heavily on **SSHKit** (a Ruby SSH parallel execution library):

- `SSHKit::DSL.on(hosts) { ... }` — parallel SSH execution
- `on_roles(roles, hosts:, parallel:) { |host, role| ... }` — custom DSL extension that runs each role in its own thread with separate connections
- `SSHKit::Backend::Netssh` — connection pool with idle timeout, max concurrent starts, DNS retries
- `Concurrent::Semaphore` limits simultaneous SSH connection starts (`max_concurrent_starts`)
- `SSHKit::Runner::Parallel` is patched to `CompleteAll` — waits for ALL threads to finish, collecting all errors instead of failing on the first

```ruby
# lib/kamal/sshkit_with_ext.rb: CompleteAll module
module CompleteAll
  def execute
    threads = hosts.map { |host| Thread.new(host) { ... } }
    exceptions = []
    threads.each { |t| t.join rescue exceptions << e }
    raise exceptions.first || exceptions.first, "Exceptions on #{exceptions.count} hosts: ..."
  end
end
```

- `SSHKit::Backend::Netssh::DnsRetriable` — retries DNS resolution with exponential backoff + jitter
- `SSHKit::Backend::Netssh::LimitConcurrentStartsInstance` — semaphore-based concurrency control on SSH connection establishment

### 2.7 Health Checks + Barrier Pattern

**Implementation:** `lib/kamal/cli/healthcheck/poller.rb` + `lib/kamal/cli/healthcheck/barrier.rb`

**Barrier:** A thread-synchronized `Concurrent::IVar` that blocks until all primary hosts have signaled readiness.

```ruby
# lib/kamal/cli/healthcheck/barrier.rb
class Barrier
  def initialize
    @ivar = Concurrent::IVar.new
  end
  def close; set(false); end    # halt on error
  def open; set(true); end      # signal ready
  def wait; raise unless opened?; end
end
```

**Poller:** Polls container health status with exponential backoff:

```ruby
# lib/kamal/cli/app.rb
barrier = Kamal::Cli::Healthcheck::Barrier.new

host_boot_groups.each do |hosts|
  on_roles(KAMAL.roles, hosts: hosts) do |host, role|
    Kamal::Cli::App::Boot.new(host, role, self, version, barrier).run
  end
end
```

Primary hosts open the barrier first; secondary hosts wait at the barrier until primary is healthy.

---

## 3. What Kamal Has That Configr Doesn't

### 3.1 Multi-Host Fundamentals

| Feature | Kamal | configr |
|---------|-------|---------|
| **Role-based server grouping** | `servers: { web: [...], workers: [...] }` with per-role env/logging/proxy | ❌ None. Single target only |
| **Host filtering with globs** | `--hosts "web*.example.com"` / `--roles "web,workers"` | ❌ None. `--host` is exact match only |
| **Serialized boot groups** | `host_boot_groups.each_slice(boot.limit)` + `boot.wait` | ❌ None |
| **Parallel SSH execution** | SSHKit `on(hosts)` with thread pool, DNS retries, concurrency limits | ⚠️ `SSHExecutionService` runs commands sequentially |
| **Primary host concept** | `primary_role` + `primary_host` for lock, coordination | ⚠️ `primary_host` exists for SSH connection only |
| **Accessories (sidecars)** | db/redis/search containers with their own hosts, roles, tags | ❌ None |
| **Host tagging** | `web2.example.com: experiments,three` → per-host env tags | ❌ None |

### 3.2 Config Composition & Destination Merging

| Feature | Kamal | configr |
|---------|-------|---------|
| **Destination config merging** | `deploy.yml` + `deploy.staging.yml` deep-merged with ERB | ❌ None. Single config file |
| **ERB preprocessing** | `ERB.new(template).result` before YAML parse | ⚠️ `template` block has Liquid/Mustache but config itself is static |
| **Config validation via docs-as-schema** | `docs/configuration.yml` is both documentation AND validation schema | ⚠️ `ConfigValidator` exists but is not schema-driven from docs |
| **`kamal config` command** | Displays merged config with secrets redacted (`Kamal::Utils.redacted`) | ⚠️ `config` command exists but doesn't show full merged state with redactions |

### 3.3 Lifecycle Hooks System

**Implementation:** `lib/kamal/commands/hook.rb` + `lib/kamal/cli/base.rb` (`run_hook`)

Kamal runs shell scripts at lifecycle points with rich environment variables:

| Hook | When |
|------|------|
| `pre-connect` | Before first SSH connection |
| `pre-deploy` | Before deploy starts (after image push) |
| `post-deploy` | After deploy completes |
| `pre-app-boot` | Before booting app containers (per host group) |
| `post-app-boot` | After booting app containers (per host group) |
| `pre-proxy-reboot` | Before proxy reboot |
| `post-proxy-reboot` | After proxy reboot |

**Hook environment variables (via `Kamal::Tags`):**
- `KAMAL_RECORDED_AT`, `KAMAL_PERFORMER`, `KAMAL_DESTINATION`, `KAMAL_VERSION`, `KAMAL_SERVICE_VERSION`, `KAMAL_SERVICE`
- Plus: `KAMAL_HOSTS`, `KAMAL_ROLES`, `KAMAL_LOCK`, `KAMAL_COMMAND`, `KAMAL_SUBCOMMAND`

```ruby
# lib/kamal/cli/base.rb: run_hook
def run_hook(hook, **extra_details)
  details = {
    hosts: KAMAL.hosts.join(","),
    roles: KAMAL.specific_roles&.join(","),
    lock: KAMAL.holding_lock?.to_s,
    command: command,
    subcommand: subcommand
  }
  with_env KAMAL.hook.env(**details, **extra_details) do
    KAMAL.with_verbosity(hook_verbosity) do
      run_locally { execute *KAMAL.hook.run(hook) }
    end
  end
end
```

**Configr comparison:** configr has `pre_apply_scripts`/`post_apply_scripts` in config and Lua/script hooks in `HookManager`, but no standard lifecycle hook names, no auto-injected environment variables, and no hook directory convention with per-hook files.

### 3.4 Lock & Concurrency Control

**Implementation:** `lib/kamal/commands/lock.rb` + `lib/kamal/cli/base.rb` (`with_lock`, `acquire_lock_with_wait`)

Kamal uses a **mkdir-based distributed mutex** on remote hosts:

```ruby
# lib/kamal/commands/lock.rb
def acquire(message, version)
  combine \
    [ :mkdir, lock_dir ],
    write_lock_details(message, version)
end

def release
  combine \
    [ :rm, lock_details_file ],
    [ :rm, "-r", lock_dir ]
end
```

Lock directory: `.kamal/lock-#{service}-#{destination}`

Features:
- `--lock-wait` polls until lock is released (configurable timeout + interval)
- Lock status shows who locked it, when, and the version
- Lock release on success or failure (ensure block)
- Lock held by `modify` wrapper in CLI

**Configr comparison:** configr's lockfile (`v2_lockfile_manager.dart`) is an apply-tracking mechanism — it records what was applied but does **not** prevent concurrent runs.

### 3.5 Audit Logging

**Implementation:** `lib/kamal/commands/auditor.rb` + `lib/kamal/tags.rb`

Every significant action is logged remotely via `echo >> .kamal/app-#{destination}.log`:

```ruby
# lib/kamal/commands/auditor.rb
def record(line, **details)
  combine \
    make_run_directory,
    append([ :echo, escape_shell_value(audit_line(line, **details)) ], audit_log_file)
end
```

Audit lines are prefixed with Kamal tags:

```ruby
# lib/kamal/tags.rb
def to_s
  tags.values.map { |value| "[#{value}]" }.join(" ")
end
# => "[2024-01-15T10:30:00Z] [user@example.com] [staging] [abc1234] [myapp@abc1234] [myapp]"
```

**Configr comparison:** configr has an in-memory `EventBus` and `FileEventHandler` for JSONL audit logs locally, but no remote audit trail tied to deployment actions.

### 3.6 Sensitive Value Redaction + Env File Generation

**Implementation:** `lib/kamal/utils/sensitive.rb` + `lib/kamal/env_file.rb`

**Redaction:**
Kamal wraps sensitive values in a class that implements both `SSHKit::Redaction` (for transport/output) and `encode_with` (for YAML serialization):

```ruby
class Kamal::Utils::Sensitive
  include SSHKit::Redaction
  delegate :to_s, to: :unredacted
  delegate :inspect, to: :redaction
  
  def encode_with(coder)
    coder.represent_scalar nil, redaction
  end
end
```

All secret lookups through `Kamal::Secrets#[]` and `Kamal::Utils.sensitive` produce `Sensitive` objects that are automatically redacted in SSHKit output and YAML dumps.

**Env file generation:**
Kamal generates Docker-compatible `.env` files on remote hosts:

```ruby
# lib/kamal/configuration/env.rb
def secrets_io
  Kamal::EnvFile.new(aliased_secrets).to_io
end
```

```ruby
# lib/kamal/env_file.rb
class Kamal::EnvFile
  def to_s
    @env.each { |key, value| contents << "#{key}=#{escape_docker_env_file_value(value)}\n" }
  end
end
```

These env files are uploaded to `.kamal/env/` and mounted into containers via `--env-file`.

**Configr comparison:** configr has `SensitiveValue` with redaction in events, but no transport-level integration. It injects secrets into process env but doesn't generate files for remote services.

### 3.7 Git Metadata Tagging

**Implementation:** `lib/kamal/git.rb` + `lib/kamal/tags.rb`

Kamal automatically derives version and performer info from Git:

```ruby
# lib/kamal/git.rb
module Kamal::Git
  def revision; `git rev-parse HEAD`.strip; end
  def user_name; `git config user.name`.force_encoding(Encoding::UTF_8).strip; end
  def email; `git config user.email`.strip; end
  def uncommitted_changes; `git status --porcelain`.strip; end
end
```

```ruby
# lib/kamal/configuration.rb
def version
  @declared_version.presence || ENV["VERSION"] || git_version
end

def git_version
  if Kamal::Git.used?
    [ Kamal::Git.revision, uncommitted_suffix ].compact.join
  end
end
```

Every command execution is tagged with `[timestamp] [performer] [destination] [version] [service_version] [service]` via `Kamal::Tags`.

**Configr comparison:** configr's `SystemInfo` gathers OS/host facts but has no Git integration or deployment metadata tagging.

### 3.8 Command Aliases

**Implementation:** `lib/kamal/configuration/alias.rb` + `lib/kamal/cli/alias/command.rb`

Aliases let users define custom CLI commands in config:

```yaml
aliases:
  uname: server exec 'uname -a'
  console: app exec 'bin/rails console'
```

```ruby
# lib/kamal/cli/alias/command.rb
class Kamal::Cli::Alias::Command < Thor::DynamicCommand
  def run(instance, args = [])
    if (command = KAMAL.resolve_alias(name))
      KAMAL.reset
      Kamal::Cli::Main.start(Shellwords.split(command) + ARGV[1..-1])
    else
      super
    end
  end
end
```

Thor's `dynamic_command_class` allows alias commands to be resolved at runtime.

**Configr comparison:** configr has no alias mechanism.

### 3.9 Builder Architecture (Multi-Strategy)

**Implementation:** `lib/kamal/configuration/builder.rb` + `lib/kamal/commands/builder/`

Kamal supports multiple build strategies for Docker images:

| Strategy | Class | Description |
|----------|-------|-------------|
| `docker` | `Builder::Local` | Local Docker build |
| `docker-container` | `Builder::Local` | Local build in Docker container |
| `remote` | `Builder::Remote` | Remote Docker build via SSH |
| `hybrid` | `Builder::Hybrid` | Local + remote arch split |
| `cloud` | `Builder::Cloud` | Cloud-based build (e.g., `cloud://`) |
| `pack` | `Builder::Pack` | Cloud Native Buildpacks |

```ruby
# lib/kamal/configuration/builder.rb
def local?
  !local_disabled? && (arches.empty? || local_arches.any?)
end

def remote?
  remote_arches.any?
end

def cloud?
  driver.start_with? "cloud"
end
```

**Configr comparison:** configr has no concept of build strategies or artifact management.

---

## 4. What Kamal Already Has That configr Also Has

Kamal and configr share several architectural patterns:

1. **SSH transport layer** — Both use SSHKit (Kamal) and `dartssh2` (configr) for remote execution. The abstractions are comparable.
2. **Secrets resolution** — Both support URI-based or adapter-based secret fetching. Kamal uses dotenv files + external adapters; configr uses `SecretResolver` with URI prefixes.
3. **Event/tagging system** — Kamal uses `Tags` for audit trails; configr uses `EventBus` with typed events and correlation IDs.
4. **Rollback** — Kamal redeploys previous version; configr uses lockfile-based `ActionBlock.rollback()`. Different approaches but both present.
5. **Dry-run / preview** — Kamal has `--dry-run` support in some commands; configr has `dryRun` flag.
6. **Plugin extensibility** — Kamal has accessory/registry/proxy subsystems; configr has Lua/Dart plugin system.

---

## 5. Key Design Patterns Worth Adopting

### 5.1 Docs-as-Schema Validation (Low Effort, High Value)

**How Kamal does it:** `lib/kamal/configuration/validation.rb`

Every configuration class includes `Kamal::Configuration::Validation`. The `validation_doc` class method loads a YAML file from `docs/` that serves **double duty** as documentation and validation schema:

```ruby
class Kamal::Configuration::Validation
  def validate!(config, example: nil, context: nil, with: Kamal::Configuration::Validator)
    example ||= validation_yml[self.class.validation_config_key]
    with.new(config, example: example, context: context).validate!
  end
end
```

The `Validator` recursively checks types, unknown keys, and specific constraints (e.g., servers format, SSH config, hooks_output enum).

**Why configr should adopt this:** configr currently validates block properties at runtime inside `readAdditionalProperties`. A schema-driven approach would catch errors earlier and provide better error messages. The YAML docs could live alongside `lib/src/blocks/` as `docs/block_type.yml`.

**Reference:** `lib/kamal/configuration/validator.rb`, `lib/kamal/configuration/docs/*.yml`

### 5.2 Destination Config Merging (Medium Effort, High Value)

**How Kamal does it:** `Configuration.load_raw_config` deep-merges base + destination YAML with ERB preprocessing.

**Why configr should adopt this:** Currently configr requires a single config file. A destination merge system (`config` + `config.staging`) enables environment overlays without duplicating the entire configuration.

**Reference:** `lib/kamal/configuration.rb:28-47`

### 5.3 Serialized Boot Groups / Gradual Rollout (Medium Effort, High Value)

**How Kamal does it:** `host_boot_groups.each_slice(limit)` with `boot.wait` sleep between groups.

**Why configr should adopt this:** For multi-host configr, a `serial` or `boot.limit` property would enable rolling updates and reduce blast radius of failures.

**Reference:** `lib/kamal/configuration/boot.rb`, `lib/kamal/cli/app.rb:365-367`

### 5.4 Lock with Wait-Polling (Low Effort, High Value)

**How Kamal does it:** `mkdir`-based lock on remote host with configurable wait timeout (`--lock-wait`).

**Why configr should adopt this:** configr's lockfile doesn't prevent concurrent runs. A distributed mutex would prevent race conditions during multi-host apply.

**Reference:** `lib/kamal/commands/lock.rb`, `lib/kamal/cli/base.rb:135-184`

### 5.5 Transport-Level Sensitive Redaction (Medium Effort, High Value)

**How Kamal does it:** `Utils::Sensitive` includes `SSHKit::Redaction`, making SSHKit automatically substitute `[REDACTED]` in output. Also implements `encode_with` for YAML serialization safety.

**Why configr should adopt this:** configr redacts in `ActionBlock` but misses transport-level output paths. A value wrapper that integrates with `ExecutionService` would catch all output.

**Reference:** `lib/kamal/utils/sensitive.rb:4-6` (`SSHKit::Redaction`)

### 5.6 Lifecycle Hooks with Rich Env Injection (Medium Effort)

**How Kamal does it:** `run_hook` in `Cli::Base` injects `KAMAL_*` env vars and runs local scripts.

**Why configr should adopt this:** configr's hook system is present but lacks standard env vars, lifecycle event naming, and hook directory conventions.

**Reference:** `lib/kamal/cli/base.rb:224-254`, `lib/kamal/commands/hook.rb`

### 5.7 Git Versioning + Tagging (Low Effort)

**How Kamal does it:** `Kamal::Git` derives version from `git rev-parse HEAD` with uncommitted detection. Tags are prepended to every audit line.

**Why configr should adopt this:** For configr managing fleets, git-derived version tags + performer metadata would dramatically improve auditability.

**Reference:** `lib/kamal/git.rb`, `lib/kamal/tags.rb`

### 5.8 Health Check Barrier Pattern (Medium Effort)

**How Kamal does it:** `Concurrent::IVar`-based barrier where primary hosts signal readiness, secondary hosts wait.

**Why configr should adopt this:** configr has `wait_for` block but no formal health-check barrier. This pattern is useful for orchestrating services that depend on others becoming healthy first.

**Reference:** `lib/kamal/cli/healthcheck/barrier.rb`

---

## 6. Code Path References

### Kamal (multi-host core)

| Feature | Path | Key Classes/Functions |
|---------|------|----------------------|
| Commander singleton | `lib/kamal/commander.rb` | `Kamal::Commander`, `config`, `specific_hosts`, `specific_roles` |
| Config loading | `lib/kamal/configuration.rb` | `Configuration.create_from`, `load_raw_config`, `load_config_files` |
| ERB + YAML parsing | `lib/kamal/configuration.rb:37-47` | `load_config_file` (ERB → YAML) |
| Servers | `lib/kamal/configuration/servers.rb` | `Servers`, `role_names` |
| Role | `lib/kamal/configuration/role.rb` | `Role`, `hosts`, `tagged_hosts`, `env(host)`, `specializations` |
| Accessory | `lib/kamal/configuration/accessory.rb` | `Accessory`, `hosts_from_tags`, `hosts_from_roles` |
| SSH | `lib/kamal/configuration/ssh.rb` | `Ssh`, `options`, `proxy` (Jump/Command) |
| Boot | `lib/kamal/configuration/boot.rb` | `Boot`, `limit`, `wait`, `parallel_roles` |
| Builder | `lib/kamal/configuration/builder.rb` | `Builder`, `local?`, `remote?`, `cloud?`, `cache_from` |
| Env | `lib/kamal/configuration/env.rb` | `Env`, `clear_args`, `secrets_io`, `merge` |
| Env Tag | `lib/kamal/configuration/env/tag.rb` | `Env::Tag` |
| Proxy | `lib/kamal/configuration/proxy.rb` | `Proxy`, `deploy_options`, `ssl?`, `hosts` |
| Registry | `lib/kamal/configuration/registry.rb` | `Registry`, `local?`, `lookup` |
| Alias | `lib/kamal/configuration/alias.rb` | `Alias` |
| Validation | `lib/kamal/configuration/validation.rb` | `Validation` module, `validation_doc`, `validate!` |
| Validator | `lib/kamal/configuration/validator.rb` | `Validator`, `validate_against_example!` |
| CLI entry | `lib/kamal/cli.rb` | `KAMAL = Kamal::Commander.new` |
| CLI base | `lib/kamal/cli/base.rb` | `Base < Thor`, `with_lock`, `run_hook`, `on` override |
| CLI main | `lib/kamal/cli/main.rb` | `Main#deploy`, `Main#setup`, `Main#rollback`, `Main#config` |
| CLI app | `lib/kamal/cli/app.rb` | `App::Boot`, `host_boot_groups`, `barrier` |
| CLI proxy | `lib/kamal/cli/proxy.rb` | `Proxy#boot`, `Proxy#reboot`, rolling upgrade |
| CLI lock | `lib/kamal/cli/lock.rb` | `Lock#acquire`, `Lock#release`, `Lock#status` |
| Commands base | `lib/kamal/commands/base.rb` | `Base#run_over_ssh`, command combinators |
| Commands app | `lib/kamal/commands/app.rb` | `App#run`, `App#stop`, `App#status` |
| Commands hook | `lib/kamal/commands/hook.rb` | `Hook#run`, `Hook#env`, `Hook#hook_exists?` |
| Commands lock | `lib/kamal/commands/lock.rb` | `Lock#acquire` (mkdir), `Lock#release` (rm -r) |
| Commands auditor | `lib/kamal/commands/auditor.rb` | `Auditor#record`, `Auditor#reveal` |
| Secrets | `lib/kamal/secrets.rb` | `Secrets#[]`, dotenv loading, mutex |
| Secrets adapters | `lib/kamal/secrets/adapters/base.rb` | `Base#fetch`, `login`, `fetch_secrets`, `check_dependencies!` |
| Secrets adapters registry | `lib/kamal/secrets/adapters.rb` | `Adapters.lookup`, `adapter_class` |
| SSHKit extensions | `lib/kamal/sshkit_with_ext.rb` | `CompleteAll`, `DnsRetriable`, `LimitConcurrentStarts`, `SSHKitDslRoles` |
| Tags | `lib/kamal/tags.rb` | `Tags`, `default_tags`, `env` (KAMAL_* vars) |
| Git | `lib/kamal/git.rb` | `Git.revision`, `Git.user_name`, `Git.uncommitted_changes` |
| Sensitive | `lib/kamal/utils/sensitive.rb` | `Sensitive` (SSHKit::Redaction + encode_with) |
| EnvFile | `lib/kamal/env_file.rb` | `EnvFile#to_s` (Docker-compatible .env) |
| Output formatter | `lib/kamal/output/formatter.rb` | `Formatter < SSHKit::Formatter::Pretty` |
| File logger | `lib/kamal/output/file_logger.rb` | `FileLogger` (ActiveSupport::Notifications-based) |
| Health barrier | `lib/kamal/cli/healthcheck/barrier.rb` | `Barrier` (Concurrent::IVar) |
| Health poller | `lib/kamal/cli/healthcheck/poller.rb` | `Poller.wait_for_healthy` |

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
| Retry | `lib/src/utils/retry_handler.dart` | `RetryHandler` |
| Secrets | `lib/src/secrets/secret_resolver.dart` | URI-based secret resolution |

---

## 7. What Configr Has That Kamal Doesn't

For balance, here are areas where configr is stronger:

1. **Rollback support** — configr has `ActionBlock.rollback()` with lockfile-based reverse execution. Kamal relies on redeploying a previous image; it has no true rollback of individual operations.
2. **Dry-run preview** — configr's `dryRun` flag skips execution but records state. Kamal's `--dry-run` support is limited and command-specific.
3. **Rich event system** — configr's `EventBus` with typed events, correlation IDs, and structured subscriptions is more robust than Kamal's `ActiveSupport::Notifications` + `BroadcastLogger` approach.
4. **Lua scripting** — configr supports Lua hooks and plugins; Kamal only supports shell scripts.
5. **Wide operational coverage** — configr's 60+ blocks cover files, packages, services, users, firewalls, etc. Kamal is Docker-only.
6. **File watching** — configr has `ConfigWatcher`; Kamal has no file-watching capability.
7. **Privilege escalation** — configr has `PrivilegeEscalation` and `PersistentPrivilegeEscalation`; Kamal runs everything as the configured SSH user.

---

## 8. Conclusion & Next Steps

### Strategic Gap

configr is a **single-target configuration management tool** with excellent execution abstractions and rollback support. Its biggest gap for multi-host use is the lack of an **inventory system, target abstraction, and host variable model**. Kamal demonstrates that these concerns—roles, destinations, serialized groups, SSHKit parallelism—can be layered cleanly on top of an SSH transport backend without changing the core execution model.

### Recommended Adoption Priority

| Priority | Feature | Effort | Impact |
|----------|---------|--------|--------|
| **P1** | Docs-as-schema validation | Low | Improves error messages, catches config bugs early |
| **P1** | Destination config merging | Medium | Enables environment overlays without duplication |
| **P2** | Lock with wait-polling | Low | Prevents concurrent apply races |
| **P2** | Transport-level sensitive redaction | Medium | Prevents secret leaks in all output paths |
| **P2** | Serialized boot groups | Medium | Enables rolling updates |
| **P2** | Git versioning + tagging | Low | Improves audit trail |
| **P3** | Lifecycle hooks with env injection | Medium | Makes hooks more powerful and standard |
| **P3** | Health-check barrier pattern | Medium | Enables dependent orchestration |
| **P3** | Command aliases | Low | UX improvement for complex configs |

### Non-Goals

- **Do not copy Kamal's Docker focus** — configr is a general-purpose config management tool, not a container deployer.
- **Do not adopt Thor** — configr's existing CLI is custom-built.
- **Do not replace i3config syntax** — It is a differentiator. Extend with `target`, `role`, `serial` keywords rather than switching to YAML.
