# Portable Targets Assessment Plan

**Date:** 2026-06-30  
**Scope:** Plan for assessing and porting Configr's blocks, hooks, plugins, tests, and remote execution model across Linux, macOS, and Windows targets.

---

## 1. Executive Summary

Configr is moving from "runs on the controller and mostly assumes Linux/POSIX" to "runs from a controller and applies configuration against a target runtime." That target can be:

- The local machine.
- A Linux SSH target.
- A macOS SSH target.
- Eventually a Windows SSH/PowerShell target.
- A Docker/container-backed integration environment.

The current codebase has the right direction:

- `ExecutionService` abstracts process execution.
- `FileSystem` can be local or SFTP-backed.
- `NetworkService` has started moving network operations behind a target-aware abstraction.
- `file_lualike` and `process_lualike` give Lua code injectable file and process behavior.
- `HookManager` now needs to consistently use the same runtime abstractions for Lua and shell hooks.

But the module surface is still uneven:

- Some blocks use Dart `Platform.*`, `dart:io`, or local filesystem semantics directly.
- Some tests assume `/tmp`, Bash, GNU userland, Linux tools, or root/systemd.
- Some blocks are inherently Linux-only and need explicit platform declarations.
- Windows needs a separate strategy for many operations, similar to Ansible's `win_*` split.

This document lays out a full assessment and migration plan. The goal is not to make every block magically work everywhere. The goal is to make platform support explicit, tested, and reliable.

---

## 2. Current State

### 2.1 What We Already Have

**Runtime abstractions:**

- `ExecutionService`
  - `LocalExecutionService`
  - `SSHExecutionService`
- `FileSystem`
  - local filesystem
  - SFTP-backed filesystem through `file_sftp`
- `NetworkService`
  - local HTTP/DNS/TCP/ping/download
  - SSH/remote-backed HTTP/download/probes using target tools where available
- Lua runtime injection
  - `file_lualike: ^0.1.1`
  - `process_lualike: ^0.1.0`
  - `lualike: ^0.2.4`

**Remote execution direction:**

- Configr should run on the controller.
- Config files, lockfiles, local plugins, local hooks, and orchestration stay on the controller.
- Block side effects happen against the active target runtime.
- For SSH targets, file operations should go through SFTP-backed `FileSystem`.
- For SSH targets, process operations should go through `ExecutionService`.
- Lua file/process APIs should use the target filesystem/process backend.

**Integration test structure:**

- `test/integration/sweep_test.dart` discovers fixtures in `test/integration/configs/`.
- Each fixture can provide:
  - `config`
  - `setup.sh`
  - `verify.sh`
  - `cleanup.sh`
  - `tags`
  - `args`
  - `out_contains`
  - `out_not_contains`
- Existing sweep fixtures are mostly Linux/POSIX shell oriented.

### 2.2 Current Problems

**Platform assumptions in code:**

- `Platform.operatingSystem`, `Platform.localHostname`, and similar host facts may describe the controller, not the target.
- Direct `Process.run` bypasses `ExecutionService`.
- Direct `dart:io File` usage can bypass the target filesystem.
- Direct HTTP/DNS/socket calls bypass target network perspective.
- Shell commands often assume Linux tools and GNU option formats.

**Platform assumptions in tests:**

- `/tmp/...` paths assume POSIX.
- `bash setup.sh`, `verify.sh`, `cleanup.sh` assume Bash exists and behaves consistently.
- Scripts assume Linux commands such as `grep`, `test`, `rm`, `touch`, `useradd`, `systemctl`, `timedatectl`, `sysctl`, `mount`, `ufw`, `firewall-cmd`.
- Existing "unit" CI command can pick up untagged integration files because not all integration tests are tagged consistently.

**Remote hooks gap:**

- Lua hooks can use injected file/process backends.
- Shell/Bash hooks must be copied to the remote target before execution when applying over SSH.
- Shell hooks are not portable across Windows targets.

**Windows target gap:**

- POSIX shell commands do not map cleanly to Windows.
- PowerShell is the natural command backend for Windows.
- Ansible handles this with explicit Windows modules such as `win_uri`, `win_get_url`, `win_user`, `win_group`, `win_service`, and `win_file`.
- Configr currently does not have a Windows-native block strategy layer.

---

## 3. Reference Model From Ansible

Ansible is useful here because it supports the same broad topology:

- Controller runs on Unix-like systems.
- Targets may be Linux, macOS, BSD, network devices, or Windows.
- SSH is the common POSIX transport.
- WinRM/PowerShell is the Windows-oriented path.

### 3.1 POSIX Modules

Many Ansible built-in modules declare platform support as `posix`.

Examples from `third_party/ansible`:

- `uri.py`
  - `platforms: posix`
  - Documentation points Windows users to `ansible.windows.win_uri`.
- `get_url.py`
  - Downloads files to the remote node.
  - Documentation says the remote server must have direct access to the resource.
  - Documentation points Windows users to `ansible.windows.win_get_url`.
- `wait_for.py`
  - `platforms: posix`
  - Documentation points Windows users to `ansible.windows.win_wait_for`.
- `template.py`
  - `platforms: posix`
  - Windows has separate `win_template` behavior.

For Configr, this suggests we should not pretend a single implementation covers every OS. We should declare target support per block and route to platform strategies.

### 3.2 macOS As a POSIX Target With Special Strategies

Ansible often treats macOS as POSIX, but with Darwin-specific branches.

Examples:

- `user.py`
  - `platforms: posix`
  - Has a `DarwinUser` implementation.
  - Uses macOS-specific user management behavior.
- `group.py`
  - `platforms: posix`
  - Has a `DarwinGroup` implementation.
- `hostname.py`
  - Has Darwin/macOS aliases.
  - Uses `scutil` for macOS hostname fields.
- `module_utils/urls.py`
  - Has Linux, BSD, SunOS, AIX, and Darwin-specific certificate path logic.

For Configr, macOS should not be "Linux with a different `Platform.operatingSystem` string." It should be a POSIX target with Darwin-specific tools and behavior.

### 3.3 Windows As A Separate Target Family

Ansible does not make the normal POSIX `uri`, `get_url`, `user`, `group`, and `service` modules handle Windows directly. It points users at Windows-specific modules.

Examples:

- `win_uri`
- `win_get_url`
- `win_user`
- `win_group`
- `win_service`
- `win_file`
- `win_template`

For Configr, we need either:

1. Separate Windows implementations behind the same block names, or
2. Separate Windows block aliases, or
3. A strategy registry where `file` resolves to `PosixFileStrategy`, `WindowsFileStrategy`, etc.

The cleanest approach is option 3: keep user-facing block names stable where semantics are truly equivalent, and make platform support explicit when semantics diverge.

---

## 4. Target Architecture

### 4.1 Target Runtime Contract

Every block should operate through a target runtime, not directly through controller globals.

Proposed object:

```dart
class TargetRuntime {
  final TargetSystemFacts facts;
  final FileSystem fileSystem;
  final ExecutionService executionService;
  final NetworkService networkService;
  final ProcessBackend? luaProcessBackend;
}
```

**Rules:**

- Blocks read/write files through `fileSystem` or `FileService`.
- Blocks run commands through `ExecutionService` or `ActionBlock.runCommand`.
- Blocks perform network operations through `NetworkService`.
- Lua hooks/plugins use `file_lualike` and `process_lualike` backends from the target runtime.
- OS facts come from the target runtime, not controller `Platform`.

### 4.2 Target Facts

We need a stable fact model:

```dart
class TargetSystemFacts {
  final String os;          // linux, macos, windows, freebsd, unknown
  final String family;      // posix, windows
  final String? distro;     // debian, ubuntu, fedora, arch, alpine, darwin
  final String? version;
  final String architecture;
  final String hostname;
  final TargetCapabilities capabilities;
}
```

Capabilities should be detected on the target:

```dart
class TargetCapabilities {
  final bool hasBash;
  final bool hasSh;
  final bool hasPowerShell;
  final bool hasCurl;
  final bool hasWget;
  final bool hasTar;
  final bool hasUnzip;
  final bool hasGzip;
  final bool hasSystemd;
  final bool hasLaunchctl;
  final bool hasSudo;
  final bool hasUseradd;
  final bool hasDscl;
  final bool hasNetsh;
  final bool hasFirewallCmd;
  final bool hasUfw;
}
```

Capability probing must happen through the target `ExecutionService`.

### 4.3 Platform Strategy Registry

Each block should expose platform support:

```dart
enum TargetPlatformFamily {
  posix,
  linux,
  macos,
  windows,
}

class BlockSupport {
  final Set<TargetPlatformFamily> supportedFamilies;
  final Set<String> requiredCapabilities;
  final bool supportsRollback;
}
```

For implementation:

```dart
abstract class BlockStrategy<TBlock extends ActionBlock> {
  bool supports(TargetSystemFacts facts);
  Future<void> execute(TBlock block, TargetRuntime runtime);
  Future<void> rollback(TBlock block, TargetRuntime runtime);
}
```

Examples:

- `HostnameBlock`
  - Linux/systemd strategy: `hostnamectl`
  - Linux/generic strategy: `/etc/hostname` + `hostname`
  - macOS strategy: `scutil --set HostName`, `ComputerName`, `LocalHostName`
  - Windows strategy: PowerShell `Rename-Computer`
- `ServiceBlock`
  - Linux/systemd strategy: `systemctl`
  - macOS strategy: `launchctl`
  - Windows strategy: PowerShell `Get-Service`, `Set-Service`, `Start-Service`
- `PackageBlock`
  - Linux: `apt`, `dnf`, `pacman`, `apk`, etc.
  - macOS: `brew`
  - Windows: likely `winget` or `choco`, but should be explicit.

### 4.4 Failure Behavior

Unsupported target behavior should be clear:

- If a block has no strategy for the target OS, fail with:
  - block name
  - target OS/family
  - required capabilities
  - suggested alternative or tag
- Dry-run should report unsupported blocks before attempting execution.
- Sweep tests should be able to assert unsupported behavior where appropriate.

---

## 5. Module Portability Assessment

The first deliverable is not implementation. It is a full module matrix.

### 5.1 Matrix Format

Create `research/block_portability_matrix.md` or generate it from metadata.

Columns:

| Block | Current implementation | Linux | macOS | Windows | Remote-safe | Rollback | Required capabilities | Notes |
|-------|------------------------|-------|-------|---------|-------------|----------|-----------------------|-------|

Values:

- `yes`
- `partial`
- `no`
- `unknown`
- `n/a`

### 5.2 Initial Block Categories

#### Category A: Should Be Portable Through FileSystem

These should work on local/SSH if they avoid platform-specific paths and use `FileSystem` correctly:

- `file`
- `copy`
- `delete`
- `move`
- `rename`
- `touch`
- `backup`
- `lineinfile`
- `blockinfile`
- `replace`
- `template`
- `stat`
- `slurp`
- `fetch`

Assessment questions:

- Does it use `fileSystem` or direct `dart:io`?
- Does rollback store enough metadata?
- Does it normalize separators or assume `/`?
- Does it use POSIX permissions or ownership fields?
- Does it work on SFTP-backed `FileSystem`?

#### Category B: Portable With Strategy Differences

These can be portable, but need target-specific process/tool strategies:

- `download`
- `uri`
- `network`
- `wait_for`
- `unarchive`
- `compress`
- `decompress`
- `script`
- `execute`
- `raw`
- `git`

Assessment questions:

- Is behavior target-side or controller-side?
- Which tool is preferred on Linux/macOS/Windows?
- Can Lua/Dart-native implementation replace shell tools?
- Can fallback be controller-download then SFTP copy?
- How is progress tracked?

#### Category C: OS Management Blocks

These need platform-specific strategies and should not be treated as generic:

- `service`
- `systemd`
- `user`
- `group`
- `hostname`
- `timezone`
- `locale_gen`
- `sysctl`
- `cron`
- `alternatives`
- `mount`
- `authorized_key`
- `known_hosts`
- `permissions`

Assessment questions:

- Is there a macOS equivalent?
- Is there a Windows equivalent?
- Is the concept Linux-only?
- Should the block fail on unsupported targets or become a no-op?
- Can the block be split into generic and platform-specific variants?

#### Category D: Linux Firewall/Package/System Blocks

These are platform-specific by nature:

- `apt`
- `dnf`
- `yum`
- `pacman`
- `apk`
- `brew`
- `ufw`
- `firewalld`
- `package`

Assessment questions:

- Should the generic `package` block dispatch by facts?
- Should explicit package-manager blocks declare a single supported OS/tool?
- What is the Windows package manager story?
- How do we avoid accidentally running package-manager tests on the wrong OS?

#### Category E: Control/Meta Blocks

These should be portable because they do not depend on target OS much:

- `echo`
- `debug`
- `fail`
- `assert`
- `set_fact`
- `gather_facts`
- `validate`
- `pause`
- `dependency`
- `container`
- `container_exec`
- `container_logs`
- `dynamic`

Assessment questions:

- Does it accidentally inspect controller facts?
- Does it use target facts where needed?
- Does it mutate target state?
- Does it need Docker availability on target?

---

## 6. Lua-Based Integration Test Plan

### 6.1 Why Move Cross-Platform Fixtures To Lua

Bash is useful for Linux containers, but it is not a portable verification language.

Lua is a better fit for Configr because:

- We already own the `lualike` runtime.
- `file_lualike` can use a custom `FileSystem`.
- `process_lualike` can use a custom `ProcessBackend`.
- Lua scripts can run on the controller while observing the target runtime.
- The same script model can validate local, SSH, and eventually Windows targets.
- It reduces per-platform shell differences in tests.

### 6.2 Sweep Fixture Extension

Extend fixture schema:

```
test/integration/configs/<fixture>/
  config
  setup.lua              # optional
  verify.lua             # preferred for portable fixtures
  verify_rollback.lua    # optional
  cleanup.lua            # preferred for portable fixtures
  setup.sh               # Linux/POSIX-specific fallback
  verify.sh
  verify_rollback.sh
  cleanup.sh
  tags
  args
  out_contains
  out_not_contains
```

Runner precedence:

1. If `setup.lua` exists, run it.
2. Else if `setup.sh` exists, run it.
3. Apply config.
4. If `verify.lua` exists, run it.
5. Else if `verify.sh` exists, run it.
6. Apply config again for idempotency.
7. If rollback enabled or `verify_rollback.*` exists, run rollback.
8. If `verify_rollback.lua` exists, run it.
9. Else if `verify_rollback.sh` exists, run it.
10. In teardown, prefer `cleanup.lua`, then `cleanup.sh`.

### 6.3 Lua Test API

Add a small Configr test Lua API:

```lua
assertFileExists(path)
assertFileNotExists(path)
assertFileContains(path, text)
assertFileEquals(path, text)
writeFile(path, text)
readFile(path)
deleteFile(path)
mkdir(path)
runCommand(command)
targetOS()
targetFamily()
hasCapability(name)
```

Most of these already exist partially through Configr's Lua library and `file_lualike`.

The sweep runner should initialize Lua verification scripts with:

- target filesystem
- target process backend
- `CONFIGR_TEST_ENV`
- config directory
- fixture directory
- target facts

### 6.4 Portable Fixture Guidelines

Portable fixtures must:

- Use relative paths inside fixture-controlled directories where possible.
- Avoid `/tmp` unless tagged `posix` or `linux`.
- Avoid shell scripts.
- Avoid OS-specific command names.
- Avoid root privileges.
- Include rollback verification when the block supports rollback.

Example:

```i3
file {
  file_path = "build/configr_cross_platform_sweep.txt"
  content = "cross-platform sweep"
  operation = "create"
  create_directories = true
}
```

`verify.lua`:

```lua
assertFileContains("build/configr_cross_platform_sweep.txt", "cross-platform sweep")
```

`verify_rollback.lua`:

```lua
assertFileNotExists("build/configr_cross_platform_sweep.txt")
```

### 6.5 Linux Fixture Guidelines

Linux fixtures may keep Bash where appropriate:

- package managers
- systemd
- users/groups
- sysctl
- mount
- firewall
- cron

But they must be tagged accurately:

- `debian`
- `ubuntu`
- `fedora`
- `arch`
- `alpine`
- `needs-root`
- `needs-systemd`
- `destructive`
- `container`

### 6.6 macOS Fixture Guidelines

macOS fixtures should use Lua for verification.

Allowed macOS-specific blocks:

- `brew`
- `hostname` once Darwin strategy exists
- `user`/`group` once Darwin strategy exists
- `service` once `launchctl` strategy exists

macOS tests should avoid:

- root/system state changes in public CI until explicitly isolated
- hostname mutation unless runner-safe
- user/group creation unless gated behind a non-default destructive tag

### 6.7 Windows Fixture Guidelines

Windows fixtures should use Lua verification or PowerShell-specific scripts only when explicitly testing Windows behavior.

Windows test requirements:

- Avoid Bash assumptions.
- Avoid POSIX paths.
- Use target-aware filesystem helpers.
- Add PowerShell strategy before testing Windows process-heavy blocks.

---

## 7. CI Migration Plan

### 7.1 Immediate State

Temporarily disabled:

- `analyze-windows`
- `analyze-macos`
- `unit-tests-windows`
- `unit-tests-macos`
- `sweep-tests` for macOS/Windows

Reason:

- The current test suite is not cleanly partitioned by platform.
- Some "unit" jobs discover integration-style tests.
- macOS/Windows sweep coverage should be re-enabled after the Lua fixture runner exists.

### 7.2 CI Layering Target

#### Linux CI

Always run:

- `dart analyze`
- pure unit tests
- Linux container sweep across distro matrix

#### macOS CI

Eventually run:

- `dart analyze`
- pure unit tests
- portable Lua sweep only
- macOS-specific block sweep when implemented

#### Windows CI

Eventually run:

- `dart analyze`
- pure unit tests
- portable Lua sweep only
- Windows-specific block sweep when implemented

### 7.3 Fix Test Classification

Current command:

```bash
dart test --exclude-tags container --exclude-tags integration
```

Problem:

- Files are not consistently tagged.
- Some integration or platform-sensitive tests may run as "unit" tests.

Target:

- Add file-level tags:
  - `@Tags(['integration'])` for `test/integration/**`
  - `@Tags(['container'])` for `test/container/**`
  - `@Tags(['multi-host'])` where needed
- Use directory-based jobs:
  - `dart test test/v2 test/secrets test/multi_host`
  - `dart test test/integration/sweep_test.dart`
  - `dart test test/container`

### 7.4 Re-enable Criteria

Re-enable macOS analyze/unit when:

- Unit test command only runs true unit tests.
- No unit test mutates Linux-only paths or tools.
- Platform-sensitive tests are tagged or skipped correctly.

Re-enable Windows analyze/unit when:

- Same as macOS.
- No test assumes POSIX path separators.
- No test assumes `/bin/sh`, `/bin/bash`, `/tmp`, chmod, symlink availability, or POSIX permissions unless tagged/skipped.

Re-enable macOS/Windows sweep when:

- Sweep runner supports Lua scripts.
- At least one portable fixture uses `verify.lua` and `verify_rollback.lua`.
- No untagged fixture runs on macOS/Windows.
- Platform-specific fixtures are correctly tagged.

---

## 8. Block Porting Roadmap

### Phase 1: Assessment And Metadata

Deliverables:

- `BlockSupport` metadata model.
- Support metadata for every built-in block.
- Generated or hand-maintained block portability matrix.
- Target facts and capabilities model finalized.
- Audit report for direct local APIs:
  - `Platform.*`
  - `Process.run`
  - `File(...)`, `Directory(...)`
  - `HttpClient`, `Socket`, `InternetAddress`
  - hard-coded `/tmp`
  - hard-coded Linux commands

Acceptance:

- Every block has declared platform support.
- Unsupported target failures are clear.
- Dry-run can report unsupported blocks.

### Phase 2: Test Harness Portability

Deliverables:

- Lua runner support in `sweep_test.dart`.
- `setup.lua`, `verify.lua`, `verify_rollback.lua`, `cleanup.lua` fixture support.
- Portable test Lua helper library.
- First portable fixture set:
  - `file`
  - `copy`
  - `delete`
  - `move`
  - `touch`
  - `template`
  - `stat`
  - `slurp`
  - `set_fact`
  - `assert`
  - `echo`

Acceptance:

- Portable Lua fixtures pass locally.
- Portable Lua fixtures pass on macOS CI.
- Portable Lua fixtures pass on Windows CI, or fail only on known unsupported runtime features.

### Phase 3: File Blocks

Port and verify:

- `file`
- `copy`
- `delete`
- `move`
- `rename`
- `touch`
- `backup`
- `lineinfile`
- `blockinfile`
- `replace`
- `template`
- `stat`
- `slurp`
- `fetch`

Key work:

- Remove direct `dart:io` where target filesystem should be used.
- Normalize relative path behavior.
- Avoid POSIX permissions unless block explicitly manages permissions.
- Verify SFTP-backed filesystem behavior.
- Verify rollback metadata.

Acceptance:

- File block portable sweep passes locally, SSH-to-Linux, macOS, and Windows where filesystem semantics allow.

### Phase 4: Process And Script Blocks

Port and verify:

- `execute`
- `raw`
- `script`
- Bash hooks
- Lua hooks
- Lua plugins

Key work:

- Define shell selection:
  - Linux/macOS: `sh` or `bash` when explicitly required.
  - Windows: PowerShell strategy.
- For remote script execution:
  - copy script to target
  - execute with selected shell/interpreter
  - cleanup target temp file
- For hooks:
  - Lua hooks are preferred for portability.
  - Bash hooks are POSIX-only unless run under a POSIX-compatible environment.
  - Windows hooks should eventually support `.ps1`.

Acceptance:

- Lua hooks/plugins use remote file/process backends.
- Bash hooks copy to SSH targets before execution.
- Process blocks fail clearly when shell/interpreter is unsupported.

### Phase 5: Network Blocks

Port and verify:

- `download`
- `uri`
- `network`
- `wait_for`
- `dependency`

Key work:

- Target-side network by default.
- Explicit controller relay for downloads.
- Tool detection per target:
  - Linux/macOS: `curl`, `openssl`, checksum tools, `nc`, DNS tools.
  - Windows: PowerShell/.NET web backend.
- Progress tracking:
  - Remote `curl` progress through temp file polling or `--write-out`.
  - Controller relay progress through Dart HTTP stream.
- Avoid extra controller hop for large remote downloads unless explicitly requested.

Acceptance:

- Linux/macOS target-side downloads work with progress.
- Controller relay mode works.
- Windows network operations either have PowerShell backend or fail with explicit unsupported errors.

### Phase 6: Archive Blocks

Port and verify:

- `compress`
- `decompress`
- `unarchive`

Key work:

- Prefer Dart archive libraries where possible for controller-local operations.
- For target-side behavior:
  - Linux/macOS: `tar`, `gzip`, `unzip` capabilities.
  - Windows: PowerShell `Compress-Archive` / `Expand-Archive`.
- Decide whether archive manipulation should happen:
  - on target
  - on controller then copied
  - configurable by `transfer_mode`

Acceptance:

- Archive fixtures pass on Linux.
- macOS support is explicit.
- Windows support is either implemented or blocked with clear errors.

### Phase 7: OS Management Blocks

Port by strategy, not by generic shell commands.

#### Hostname

- Linux/systemd: `hostnamectl`
- Linux/generic: `/etc/hostname` + `hostname`
- macOS: `scutil`
- Windows: PowerShell `Rename-Computer`

#### Service

- Linux/systemd: `systemctl`
- Linux/openrc: `rc-service`, `rc-update`
- macOS: `launchctl`
- Windows: PowerShell service cmdlets

#### User/Group

- Linux: `useradd`, `usermod`, `userdel`, `groupadd`, `groupmod`, `groupdel`
- macOS: `dscl`, `dseditgroup`
- Windows: PowerShell local user/group cmdlets

#### Timezone

- Linux/systemd: `timedatectl`
- Linux/generic: distro-specific files
- macOS: `systemsetup -settimezone`
- Windows: `tzutil`

#### Cron/Scheduler

- Linux/macOS: cron/crontab where available
- macOS alternative: launchd
- Windows: Task Scheduler

Acceptance:

- Each block has strategy-specific tests.
- Destructive/system tests are opt-in.
- Public CI avoids unsafe host mutation by default.

### Phase 8: Package And Firewall Blocks

Package managers:

- `apt`: Debian/Ubuntu only
- `dnf`: Fedora/RHEL family
- `yum`: legacy RHEL family
- `pacman`: Arch
- `apk`: Alpine
- `brew`: macOS/Linuxbrew where installed
- `package`: dispatches by target facts and tool detection
- Windows package manager support: explicit future decision (`winget`, `choco`, `scoop`)

Firewall:

- `ufw`: UFW only
- `firewalld`: firewalld only
- macOS firewall: separate strategy if needed
- Windows firewall: PowerShell `NetSecurity`

Acceptance:

- Explicit manager blocks never silently run on unsupported OS.
- Generic `package` dispatch is fact-driven.
- Tests are distro-tagged.

---

## 9. Implementation Guidelines

### 9.1 Do Not Use Controller APIs For Target Behavior

Avoid in block execution paths:

- `Platform.operatingSystem`
- `Platform.localHostname`
- `File(...)`
- `Directory(...)`
- `Process.run(...)`
- `HttpClient`
- `Socket.connect`
- `InternetAddress.lookup`

Use instead:

- target facts
- injected `FileSystem`
- `FileService`
- `ExecutionService`
- `NetworkService`

### 9.2 Explicit Controller Operations Are Allowed

Some operations are intentionally controller-side:

- Reading config files.
- Reading local hook/plugin source files.
- Reading local inventory files.
- Writing local lockfiles.
- Rendering controller-side docs/output.
- Downloading on controller when `transfer_mode = "controller"`.

These should be documented and named clearly.

### 9.3 Shell Use Requires Declaration

Any block or hook path requiring shell must declare:

- shell type
- target family
- required tool
- fallback behavior

Examples:

- Bash hook: requires POSIX target with `bash`.
- Shell hook: requires POSIX target with `sh`.
- PowerShell hook: requires Windows target with PowerShell.

### 9.4 Prefer Lua For Cross-Platform Test Logic

Lua verification should be the default for portable fixtures.

Bash verification should mean "this fixture is POSIX/Linux specific."

PowerShell verification should mean "this fixture is Windows specific."

---

## 10. Proposed Work Breakdown

### Workstream A: CI Stabilization

1. Temporarily disable macOS/Windows jobs.
2. Ensure Linux CI remains green.
3. Fix test tagging so unit jobs do not run integration tests accidentally.
4. Re-enable macOS analyze only.
5. Re-enable Windows analyze only.
6. Re-enable macOS/Windows unit jobs once pure unit command is reliable.
7. Re-enable portable sweep after Lua fixture support lands.

### Workstream B: Runtime Audit

1. Search for direct local APIs.
2. Categorize each use:
   - controller-intentional
   - target bug
   - harmless test-only
3. Replace target bugs with runtime abstractions.
4. Add regression tests.

### Workstream C: Lua Test Harness

1. Build Lua fixture runner for sweep tests.
2. Add Lua test helper functions.
3. Convert first portable fixture.
4. Convert file block fixtures.
5. Convert process/network fixtures where feasible.
6. Keep Linux shell fixtures for Linux-only modules.

### Workstream D: Block Metadata

1. Add block support metadata.
2. Add capability metadata.
3. Add unsupported target errors.
4. Generate/support documentation from metadata.

### Workstream E: Strategy Implementations

1. File blocks.
2. Process/script/hook blocks.
3. Network blocks.
4. Archive blocks.
5. OS management blocks.
6. Package/firewall blocks.

---

## 11. Assessment Deliverables

The assessment is complete when we have:

1. A block portability matrix for every built-in block.
2. A list of direct controller API usages and their classification.
3. A target facts/capabilities model.
4. A strategy recommendation for each block:
   - portable as-is
   - portable after abstraction cleanup
   - requires Linux strategy
   - requires macOS strategy
   - requires Windows strategy
   - should remain Linux-only
5. A Lua-based fixture plan for cross-platform integration coverage.
6. A CI re-enable checklist.
7. A prioritized implementation backlog.

---

## 12. Immediate Next Steps

1. Keep macOS/Windows CI disabled temporarily.
2. Add `@Tags(['integration'])` to integration tests or change CI to directory-specific unit runs.
3. Add Lua fixture runner support to `sweep_test.dart`.
4. Convert `cross_platform_file` from shell verification to Lua verification.
5. Generate the initial block portability matrix.
6. Audit direct uses of:
   - `Platform`
   - `Process.run`
   - `File`
   - `Directory`
   - `HttpClient`
   - `Socket`
   - hard-coded `/tmp`
7. Start porting Category A file blocks to prove the method.

---

## 13. Current Windows Findings To Fold Into The Plan

The first Windows failure pass exposed two different classes of issues:

1. Real portability bugs in Configr's implementation.
2. Tests that accidentally exercise controller-local or platform-default behavior instead of Configr's target runtime abstractions.

### 13.1 Windows Bugs From The Current Test Run

| Issue | Root Cause | Fix Direction |
|-------|------------|---------------|
| `generate_keys.sh` fails with `$'\r'` | Script checked out or generated with CRLF line endings | Enforce LF for shell fixtures, or generate SSH keys from Dart setup instead of shell where possible |
| Host lock paths use backslashes | Default `package:path` context follows the controller OS | Use `path.posix` for lockfile virtual paths in `MemoryFileSystem` tests and internal lock paths |
| Host rollback lock path uses backslashes | Same default path context issue | Use `path.posix` for config lock path derivation |
| Backup directory copy passes directories to `copyFile` | Directory traversal did not filter file entities | Skip directories and copy only files |
| Copy/backup nested directory layout breaks | Recursive copy used basename-only joins and recursive re-entry | Copy each entity by relative path from the source root |
| Lua plugin test hangs on Windows | Test calls `io.popen` without an injected process backend | Do not test default host shell execution in Configr's portable unit tests |

### 13.2 Path Policy

Configr needs a strict path policy because three path domains exist:

| Domain | Examples | Path Context |
|--------|----------|--------------|
| Controller-local paths | CLI config path, local docs, local plugin source, local inventory source | Host `package:path` context or local filesystem path context |
| Target paths | Remote file destinations, SFTP paths, target lock metadata | Target filesystem path context |
| In-memory test paths | `MemoryFileSystem` fixtures, unit-test lockfiles | `path.posix` unless the test explicitly validates Windows-native local paths |

Rules:

- Do not use default `p.join` for paths that are stored inside `MemoryFileSystem`.
- Do not use default `p.join` for paths that represent POSIX SFTP paths.
- Prefer `fileSystem.path` when a concrete `FileSystem` path context is available.
- Prefer `path.posix` for lockfile metadata paths and virtual paths used by cross-platform tests.
- Keep default host path behavior for controller-local paths such as the config file selected by the CLI.

### 13.3 Process Policy

Tests and blocks should not depend on the controller's default process behavior unless that is the explicit subject under test.

Rules:

- Lua plugin/hook tests that validate process integration must inject a fake or target-aware `ProcessBackend`.
- Lua plugin/hook tests that validate file integration should avoid `os.execute` and `io.popen`.
- Blocks should call `ExecutionService`, not `Process.run`, when the process affects the target.
- Shell hooks are POSIX-only unless we add a PowerShell hook type.

---

## 14. Detailed Assessment Work Items

This section turns the research into implementation-sized work. Each item should produce either metadata, a test, a code change, or a docs update.

### 14.1 Block Metadata

Add a metadata model that can live next to each block class or in a central registry.

Minimum fields:

```dart
class BlockSupportMetadata {
  final String blockType;
  final Set<String> supportedFamilies;
  final Set<String> requiredCapabilities;
  final bool supportsRollback;
  final bool mutatesTarget;
  final bool controllerOnly;
  final String supportNotes;
}
```

Acceptance criteria:

- Every registered built-in block has metadata.
- Dry-run can print unsupported-target warnings before execution.
- Docs can render the block support table from the same metadata.
- Tests assert that every block in the registry has metadata.

### 14.2 Target Facts And Capabilities

Unify target facts so blocks do not make their own decisions from controller APIs.

Facts:

- `os`: `linux`, `macos`, `windows`, `freebsd`, `unknown`
- `family`: `posix`, `windows`, `unknown`
- `distro`: `debian`, `ubuntu`, `fedora`, `arch`, `alpine`, `darwin`, `unknown`
- `version`
- `kernel`
- `architecture`
- `hostname`
- `user`
- `home`

Capabilities:

- shell: `sh`, `bash`, `powershell`
- network: `curl`, `wget`, PowerShell web request, TCP probe
- archive: `tar`, `gzip`, `zip`, `unzip`, PowerShell archive cmdlets
- services: `systemd`, `launchctl`, Windows service cmdlets
- packages: `apt`, `dnf`, `yum`, `pacman`, `apk`, `brew`, `winget`, `choco`
- firewall: `ufw`, `firewall-cmd`, PowerShell NetSecurity
- containers: Docker CLI and daemon availability

Acceptance criteria:

- Local runtime facts describe the local target.
- SSH runtime facts describe the SSH target, not the controller.
- Tests can inject fake facts without shelling out.
- Blocks consume facts through DI or runtime context.

### 14.3 Unsupported Target Errors

Unsupported behavior should fail early and plainly.

Error shape:

```text
Block "service" is not supported on target "windows".
Required: one of os.systemd, os.launchd, os.windows_service.
Detected: os=windows family=windows capabilities=exec.powershell.
Suggestion: enable the Windows service strategy or tag this block linux/macos.
```

Acceptance criteria:

- Unsupported errors include block type, target facts, required capabilities, and a useful suggestion.
- Dry-run emits the same support information without mutating the target.
- Tests cover at least one unsupported block per platform family.

### 14.4 Lua Fixture Runner

Add Lua fixture support to `test/integration/sweep_test.dart`.

Fixture lifecycle:

1. `setup.lua` if present, else `setup.sh`.
2. Apply config.
3. `verify.lua` if present, else `verify.sh`.
4. Apply config again for idempotency.
5. Rollback when fixture opts in or rollback verification exists.
6. `verify_rollback.lua` if present, else `verify_rollback.sh`.
7. `cleanup.lua` if present, else `cleanup.sh`.

Runner context:

- fixture directory
- config directory
- temp directory
- target facts
- target filesystem
- target process backend
- current test environment tag

Acceptance criteria:

- A Lua fixture can create, verify, and clean up files through the target filesystem.
- A Lua fixture can run a command through an injected process backend when explicitly needed.
- Portable fixtures do not require Bash on Windows.

### 14.5 First Portable Fixture Set

Convert these fixtures first because they prove the core model without system mutation:

1. `file`
2. `copy`
3. `delete`
4. `move`
5. `touch`
6. `lineinfile`
7. `blockinfile`
8. `replace`
9. `template`
10. `stat`
11. `slurp`
12. `set_fact`
13. `assert`
14. `echo`

Each portable fixture should include:

- `config`
- `verify.lua`
- `cleanup.lua`
- `verify_rollback.lua` when rollback is supported
- `tags` containing `portable`

Acceptance criteria:

- The portable fixture set passes on Linux.
- The portable fixture set passes on macOS.
- The portable fixture set passes on Windows or has explicit skip metadata tied to a missing target capability.

---

## 15. Remote Execution Semantics

Configr's multi-host promise depends on being precise about where work happens.

### 15.1 Controller-Side Work

These operations happen on the controller:

- Reading the config file passed to the CLI.
- Resolving includes from local config directories.
- Reading local inventory files.
- Reading local plugin source files.
- Reading local hook source files before staging.
- Writing controller-side reports.
- Writing controller-side cached downloads when `transfer_mode = "controller"`.

### 15.2 Target-Side Work

These operations happen on the active target:

- File mutations from blocks.
- Commands from blocks.
- Lua file/process operations used by hooks/plugins during target apply.
- Network calls from `download`, `uri`, `wait_for`, and `dependency` by default.
- Bash/PowerShell hook execution after the hook file is staged to the target.

### 15.3 Ambiguous Work Must Be Configurable

Some work is valid in either place:

- HTTP downloads.
- Archive creation/extraction.
- Template rendering when templates include target file reads.
- Secret resolution from command providers.

These need explicit mode fields instead of hidden behavior:

```i3
download {
  source = "https://example.com/large.tar.gz"
  destination = "/opt/app/large.tar.gz"
  transfer_mode = "target" # target | controller | auto
  allow_controller_fallback = false
}
```

Default policy:

- Remote target: prefer `target`.
- Local target: `target` and `controller` are the same runtime, so behavior is local.
- `auto` must not silently relay large downloads through the controller unless `allow_controller_fallback = true`.

---

## 16. Windows Portability Strategy

Windows should not be treated as "POSIX with backslashes." It is a separate target family.

### 16.1 What Can Be Portable Early

Likely early support:

- Controller-side analyze/unit tests.
- Pure parser/config tests.
- MemoryFileSystem-backed tests.
- File blocks that avoid POSIX permissions.
- Lua fixture verification through file helpers.
- Metadata and unsupported-target behavior.

### 16.2 What Needs Windows Strategies

Requires PowerShell or Windows API strategy:

- `execute`
- `raw`
- `script`
- `download`
- `uri`
- `wait_for`
- `dependency`
- `service`
- `user`
- `group`
- `hostname`
- `timezone`
- `cron` or scheduler behavior
- package management
- firewall management
- permissions/ACLs

### 16.3 PowerShell Backend Shape

Windows command strategy should prefer PowerShell with no profile:

```text
pwsh -NoProfile -NonInteractive -Command <script>
```

Fallback:

```text
powershell.exe -NoProfile -NonInteractive -Command <script>
```

Rules:

- Do not run through `cmd.exe` unless explicitly requested.
- Quote arguments structurally, not by string concatenation.
- Return stdout, stderr, and exit code through `ExecutionService`.
- Expose the selected shell in target facts.

### 16.4 Windows Test Rules

Windows tests must avoid:

- `/tmp`
- `/bin/sh`
- Bash scripts
- `chmod`
- `chown`
- POSIX symlink assumptions
- POSIX executable-bit assertions
- `grep`, `sed`, `awk`, `rm`, `touch` unless run inside an explicitly declared POSIX environment

Windows tests should use:

- MemoryFileSystem for unit tests.
- Lua file helper fixtures for portable integration tests.
- PowerShell fixtures only for Windows-specific behavior.

---

## 17. macOS Portability Strategy

macOS is a POSIX target, but not Linux.

### 17.1 Safe Early Coverage

Likely early support:

- analyze
- pure unit tests
- Lua portable sweep
- file blocks
- process blocks that use `/bin/sh` carefully
- Homebrew when installed and tagged

### 17.2 Darwin-Specific Strategy Work

Needs Darwin strategy:

- `hostname`: `scutil`
- `service`: `launchctl`
- `user`: `dscl`
- `group`: `dscl` / `dseditgroup`
- `timezone`: `systemsetup`
- package: `brew`
- scheduler: launchd or crontab depending on semantics

### 17.3 macOS Test Rules

macOS public CI should avoid:

- mutating hostname
- creating system users/groups
- changing timezone
- changing services
- package installs by default

Those tests should be opt-in and tagged:

- `destructive`
- `needs-sudo`
- `macos-system`

---

## 18. CI Re-Enable Plan

### 18.1 Stage 1: Linux Stabilization

Keep running:

- `dart analyze`
- unit tests
- Linux container tests
- Linux sweep tests

Exit criteria:

- Linux CI is green after Windows path-hygiene fixes.
- No unit test fills `/tmp`; CI sets `TMPDIR` to a workspace temp directory where needed.

### 18.2 Stage 2: macOS/Windows Analyze

Re-enable analyze first.

Exit criteria:

- Analyze passes on macOS.
- Analyze passes on Windows.
- No generated files or path assumptions break dependency resolution.

### 18.3 Stage 3: macOS/Windows Unit Tests

Run only true unit tests:

```bash
dart test test/v2 test/secrets test/multi_host --exclude-tags integration --exclude-tags container
```

Exit criteria:

- No Docker required.
- No Bash required on Windows.
- No Linux system mutation.
- MemoryFileSystem paths are stable across host OSes.

### 18.4 Stage 4: Portable Sweep

Run only portable Lua fixtures:

```bash
CONFIGR_TEST_ENV=portable dart test test/integration/sweep_test.dart
```

Exit criteria:

- Fixture selection honors `portable`, `linux`, `macos`, `windows`, `container`, `destructive`, and distro tags.
- Portable fixtures use Lua verification.
- Linux-only shell fixtures do not run on macOS/Windows.

### 18.5 Stage 5: Platform-Specific Sweeps

Enable platform-specific sweeps only after strategies exist.

Examples:

- macOS Homebrew fixture only when `brew` exists.
- Windows PowerShell `execute` fixture only after PowerShell strategy lands.
- Linux package/firewall fixtures only inside containers or privileged opt-in jobs.

---

## 19. Documentation Updates Required

User-facing docs should explain target behavior without exposing internal Dart structure.

Docs to add or update:

- Target runtimes: local vs SSH vs future Windows.
- What happens on the controller vs the target.
- Block platform support table generated from metadata.
- Transfer modes for downloads and HTTP.
- Hooks:
  - Lua hooks are portable and target-aware.
  - Bash hooks are POSIX-target hooks and are staged before remote execution.
  - PowerShell hooks are planned for Windows.
- Test fixture authoring:
  - portable Lua fixtures
  - Linux shell fixtures
  - platform tags
- Troubleshooting:
  - unsupported target errors
  - missing target capabilities
  - controller fallback disabled

---

## 20. Decision Log

| Decision | Status | Rationale |
|----------|--------|-----------|
| Configr runs on controller and mutates target through runtime abstractions | Accepted | Preserves multi-host architecture and avoids copying the binary to targets |
| Network blocks should run from target by default | Accepted | Target network perspective is usually what users expect and avoids controller relay for large downloads |
| Controller download fallback must be explicit | Accepted | Hidden relay can be slow, expensive, and surprising |
| Lua is the preferred portable fixture language | Accepted | We own the runtime and can inject target file/process backends |
| Bash hooks are POSIX-only for now | Accepted | Windows needs a PowerShell hook strategy instead of Bash assumptions |
| Windows is a separate target family | Accepted | POSIX semantics, paths, permissions, services, and users do not map directly |
| macOS is POSIX plus Darwin strategies | Accepted | Many operations are similar but service/user/hostname/package tooling differs |
| Not all blocks should work everywhere | Accepted | Explicit unsupported errors are better than unreliable no-ops or host-side behavior |

---

## 21. Key Design Decision

Configr should not aim for "all blocks work everywhere."

Configr should aim for:

- portable blocks where the operation is genuinely portable,
- platform strategies where the concept is portable but tools differ,
- explicit unsupported errors where the concept is not portable,
- reliable tests that prove each claim on real target families.

That is the same practical shape Ansible uses: POSIX modules, Darwin branches, Windows-specific modules, and explicit platform declarations.
