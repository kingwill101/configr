# Block Portability Matrix

**Date:** 2026-07-02
**Legend:** ✅ yes | 🔶 partial | ❌ no | ➖ n/a | ❓ unknown

## Supported Platform Scope

Configr's portability target is:

- **Linux**: primary local and SSH target. Linux-only blocks are allowed, but must declare clear unsupported-target behavior.
- **macOS**: supported local target for portable file/process/network blocks; Darwin system-management strategies are still incomplete.
- **FreeBSD**: supported target family for POSIX-style file/process/network work where tools exist; many OS-management strategies are still placeholders.
- **Windows**: supported target family through PowerShell-oriented execution strategies. Windows is not POSIX with backslashes; ACLs, services, packages, scheduled tasks, symlinks, paths, and shell quoting require native strategies.

The matrix below still groups macOS and FreeBSD together in many rows because
the current implementation usually treats both as POSIX-like unless a block has
a dedicated Darwin/FreeBSD strategy. Future updates should add an explicit
FreeBSD column once CI has a reliable FreeBSD runner or VM fixture.

## Category A: File System Blocks (should be portable via FileSystem)

| Block | Linux | macOS | Windows | Remote-safe | Rollback | Uses FileSystem? | Notes |
|-------|-------|-------|---------|-------------|----------|------------------|-------|
| file | ✅ | ✅ | 🔶 | ✅ | ✅ | ✅ | Windows: POSIX permissions/ownership n/a |
| copy | ✅ | ✅ | 🔶 | ✅ | ✅ | ✅ | Windows: POSIX perms n/a |
| delete | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | |
| move | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | |
| rename | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | |
| touch | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | |
| backup | ✅ | ✅ | 🔶 | ✅ | ✅ | ✅ | Windows: POSIX perms n/a |
| lineinfile | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | |
| blockinfile | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | |
| replace | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | |
| template | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | |
| stat | ✅ | ✅ | 🔶 | ✅ | ✅ | ✅ | Windows: POSIX mode/owner fields n/a |
| slurp | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | |
| fetch | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | |

## Category B: Process / Script / Network Blocks (portable with strategy)

| Block | Linux | macOS | Windows | Remote-safe | Rollback | ExecutionService? | Notes |
|-------|-------|-------|---------|-------------|----------|-------------------|-------|
| download | ✅ | ✅ | 🔶 | ✅ | ✅ | via NetworkService | Windows PowerShell strategy exists; needs CI fixture coverage |
| uri | ✅ | ✅ | 🔶 | ✅ | ✅ | via NetworkService | Windows PowerShell strategy exists; needs CI fixture coverage |
| network | ✅ | ✅ | 🔶 | ✅ | ❌ | via NetworkService | Windows DNS/TCP/ping strategies exist; needs CI fixture coverage |
| wait_for | ✅ | ✅ | ✅ | ✅ | ❌ | `networkService.probeTcp` / `ExecutionService.run` | macOS/Linux ping fixed, Windows ping via `-n -w` |
| unarchive | ✅ | ✅ | ❓ | ✅ | ❌ | via ExecutionService | |
| compress | ✅ | ✅ | ❓ | ❌ | ❌ | via ExecutionService | |
| decompress | ✅ | ✅ | ❓ | ❌ | ❌ | via ExecutionService | |
| script | ✅ | ✅ | 🔶 | ✅ | ❌ | ✅ | Windows strategy exists; `.ps1` hooks/scripts need explicit fixtures |
| execute | ✅ | ✅ | 🔶 | ✅ | ❌ | ✅ | PowerShell default on Windows; needs CI fixture coverage |
| raw | ✅ | ✅ | 🔶 | ✅ | ❌ | via ExecutionService | Direct executable dispatch; Windows semantics need tests |
| git | ✅ | ✅ | ❓ | ✅ | ❌ | via ExecutionService | |
| dependency | ✅ | ✅ | ✅ | ✅ | ❌ | `networkService.probeTcp` / `ExecutionService.run` | macOS/Linux ping fixed, Windows ping via `-n -w` |
| sync | ✅ | ✅ | ❓ | ✅ | ❌ | via ExecutionService | |

## Category C: OS Management Blocks (platform-specific strategies)

| Block | Linux | macOS | Windows | Remote-safe | Rollback | Notes |
|-------|-------|-------|---------|-------------|----------|-------|
| service | ✅ systemd | 🔶 launchctl | ❌ | ✅ | ✅ | macOS strategy needed |
| systemd | ✅ | ❌ | ❌ | ✅ | ✅ | Linux-only (systemd) |
| user | ✅ useradd | 🔶 dscl | ❌ | ✅ | ✅ | macOS/Darwin strategy needed |
| group | ✅ groupadd | 🔶 dseditgroup | ❌ | ✅ | ✅ | macOS/Darwin strategy needed |
| hostname | ✅ hostnamectl | 🔶 scutil | ❌ | ✅ | ✅ | macOS/Darwin strategy needed |
| timezone | ✅ timedatectl | 🔶 systemsetup | ❌ | ✅ | ✅ | macOS/Darwin strategy needed |
| locale_gen | ✅ | ❌ | ❌ | ✅ | ❌ | Linux-only concept (locales) |
| sysctl | ✅ | ❌ | ❌ | ✅ | ❌ | Linux-only (sysctl) |
| cron | ✅ | 🔶 launchd | ❌ | ✅ | ✅ | macOS: launchd alternative |
| alternatives | ✅ | ❌ | ❌ | ✅ | ❌ | Linux-only (update-alternatives) |
| mount | ✅ | ✅ | ❌ | ✅ | ❌ | |
| authorized_key | ✅ | ✅ | ❓ | ✅ | ✅ | Windows: needs SSH key story |
| known_hosts | ✅ | ✅ | ❓ | ✅ | ✅ | Windows: needs SSH key story |
| permissions | ✅ | ✅ | ❌ | ✅ | ✅ | POSIX-only concept |

## Category D: Platform-Specific Blocks (declared single-platform)

| Block | Linux | macOS | Windows | Remote-safe | Rollback | Notes |
|-------|-------|-------|---------|-------------|----------|-------|
| apt | ✅ | ❌ | ❌ | ✅ | ✅ | Debian/Ubuntu only |
| dnf | ✅ | ❌ | ❌ | ✅ | ✅ | Fedora/RHEL only |
| yum | ✅ | ❌ | ❌ | ✅ | ✅ | Legacy RHEL only |
| pacman | ✅ | ❌ | ❌ | ✅ | ✅ | Arch only |
| apk | ✅ | ❌ | ❌ | ✅ | ✅ | Alpine only |
| brew | ❌ | ✅ | ❌ | ✅ | ✅ | macOS (or Linuxbrew) |
| package | ✅ | ✅ | ❌ | ✅ | ✅ | Generic dispatcher |
| ufw | ✅ | ❌ | ❌ | ✅ | ❌ | Ubuntu firewall only |
| firewalld | ✅ | ❌ | ❌ | ✅ | ❌ | Fedora/RHEL firewall only |

## Category E: Control / Meta Blocks (portable by nature)

| Block | Linux | macOS | Windows | Remote-safe | Rollback | Notes |
|-------|-------|-------|---------|-------------|----------|-------|
| echo | ✅ | ✅ | ✅ | ✅ | ❌ | |
| debug | ✅ | ✅ | ✅ | ✅ | ❌ | |
| fail | ✅ | ✅ | ✅ | ✅ | ❌ | |
| assert | ✅ | ✅ | ✅ | ✅ | ❌ | |
| set_fact | ✅ | ✅ | ✅ | ✅ | ❌ | |
| gather_facts | ✅ | ✅ | 🔶 | ✅ | ❌ | Windows: limited facts |
| validate | ✅ | ✅ | ✅ | ✅ | ❌ | |
| pause | ✅ | ✅ | ✅ | ✅ | ❌ | |
| connection | ✅ | ✅ | ✅ | ✅ | ❌ | Controller-side |
| secrets | ✅ | ✅ | ✅ | ✅ | ❌ | Controller-side |
| dynamic | ✅ | ✅ | ✅ | ✅ | ❌ | Controller-side dispatch |
| container | ✅ | ✅ | ❓ | ❌ | ❌ | Needs Docker on target |
| container_exec | ✅ | ✅ | ❓ | ❌ | ❌ | Needs Docker on target |
| container_logs | ✅ | ✅ | ❓ | ❌ | ❌ | Needs Docker on target |

## Summary

| Category | Total | ✅ Linux | ✅ macOS | ✅ Windows | Remote-safe | Rollback |
|----------|-------|---------|---------|-----------|-------------|----------|
| A: File System | 14 | 14 | 14 | 11 | 14 | 14 |
| B: Process/Network | 12 | 12 | 12 | 2 | 10 | 3 |
| C: OS Management | 14 | 14 | 5 | 0 | 14 | 10 |
| D: Platform-specific | 9 | 8 | 1 | 0 | 9 | 7 |
| E: Control/Meta | 14 | 14 | 14 | 13 | 12 | 0 |
| **Total** | **63** | **62** | **46** | **26** | **59** | **34** |

## Further Portability Work Required

This is the current work queue after the remote execution, audit logging,
Windows import hardening, Lua plugin process fallback, Unix ping shell wrapping,
and fail-fast processor changes.

### P0: Make Platform Support Explicit

| Work Item | Why It Matters | Target Outcome |
|-----------|----------------|----------------|
| Add block-level capability metadata | The tables are still mostly documentation. The runtime should know which capabilities each block requires. | Each block declares required capabilities such as `fs.write`, `exec.powershell`, `os.systemd`, `pkg.apt`, `fw.ufw`. |
| Add early unsupported-target checks | Many unsupported blocks fail only after command execution starts. | Dry-run and apply can fail before mutation with block type, target OS, missing capability, and suggestion. |
| Normalize local vs target facts | Some factories still use controller `Platform`/`OsFacts.detect()` instead of target facts. | Blocks use target facts from the processor context; constructors stay platform-neutral. |
| Add FreeBSD as a first-class matrix dimension | The docs mention FreeBSD, but this matrix mostly folds it into POSIX/macOS assumptions. | Matrix tables and tests distinguish Linux, macOS, FreeBSD, and Windows. |
| Keep fail-fast at processor boundary | `--fail-fast` now halts on processor/block errors; nested manual processing paths need continued audit. | Dynamic/manual processing code cannot continue after a recorded fatal error. |

### P1: Test Harness And CI

| Work Item | Why It Matters | Target Outcome |
|-----------|----------------|----------------|
| Portable Lua sweep fixtures | Shell `verify.sh`/`cleanup.sh` fixtures are not portable to Windows and are weak on macOS/FreeBSD. | Portable fixtures use `verify.lua`, `cleanup.lua`, and optional `verify_rollback.lua`. |
| Platform tags and capability tags | OS tags alone are too coarse for tools like `tar`, `curl`, `bash`, `systemctl`, Docker, and package managers. | Fixture tags include `portable`, `linux`, `macos`, `freebsd`, `windows`, `requires-bash`, `requires-docker`, `requires-systemd`, etc. |
| Re-enable analyze/unit jobs by platform | Linux-only tests and host-mutating tests must not block macOS/Windows/FreeBSD confidence. | CI has separate Linux, macOS, Windows, and FreeBSD or VM-backed jobs with correct skips. |
| Container-backed Linux distro matrix | Package/firewall blocks need real tools but should not mutate the host. | apt/dnf/yum/pacman/apk/firewalld/ufw tests run only in containers or privileged opt-in jobs. |
| Windows SSH target fixture | Local Windows behavior and remote Windows behavior are different. | CI or manual fixture covers OpenSSH + PowerShell target execution and SFTP file operations. |

### P1: Windows Runtime And Blocks

| Work Item | Why It Matters | Target Outcome |
|-----------|----------------|----------------|
| Windows ACL strategy for `permissions` | POSIX chmod/chown semantics do not map to Windows. | `permissions` either supports Windows ACLs or fails early with required capability metadata. |
| Windows service strategy | Generic `service` currently has no Windows implementation. | `service` uses PowerShell service cmdlets on Windows. |
| Windows scheduled task strategy | `cron` is Linux-only today, but scheduled jobs are a portable concept. | Either add a Windows-specific task block or make a scheduler abstraction. |
| Windows package manager policy | `package` has no Windows manager story. | Decide and implement `winget`, `choco`, and/or `scoop` capability strategy. |
| Windows firewall strategy | `ufw`/`firewalld` are Linux-only. | Add separate Windows firewall strategy using PowerShell NetSecurity or document unsupported. |
| Windows archive strategy | Archive blocks rely heavily on POSIX tools. | Use PowerShell `Compress-Archive`/`Expand-Archive` where possible, with explicit unsupported errors for tar/gzip gaps. |
| PowerShell hooks and scripts | Bash hooks are POSIX-only. | Hook manager supports `.ps1` on Windows and fails clearly when `.sh` requires missing Bash. |
| Windows path and home lookup policy | `$HOME`, OpenSSH paths, symlink behavior, temp paths, and drive roots differ from POSIX. | Shared path helpers and target facts provide Windows-safe home/temp/SSH locations. |

### P1: macOS And FreeBSD Strategies

| Work Item | Why It Matters | Target Outcome |
|-----------|----------------|----------------|
| macOS service strategy | `service` lists launchctl as partial but strategy is incomplete. | `service` can manage launchd services or explicitly rejects unsupported states. |
| macOS user/group strategy | Docs mention `dscl`/`dseditgroup`; code still has stubs. | `user` and `group` use Darwin tools or fail early with capability metadata. |
| macOS hostname/timezone strategy validation | Docs claim support in places, but code has stubs for hostname and partial timezone semantics. | `hostname` and `timezone` have real Darwin tests. |
| FreeBSD user/group/hostname strategies | FreeBSD is listed as supported in docs for some blocks, but implementation is mostly stubs. | `pw`, rc/service, hostname, mount, and package expectations are explicit. |
| macOS/FreeBSD package policy | Homebrew covers macOS and Linuxbrew, but FreeBSD package support is not declared. | Decide whether to add `pkg` block/capability for FreeBSD. |
| cron vs launchd vs rc semantics | Scheduling/service concepts differ across POSIX families. | Avoid pretending Linux cron/systemd semantics are portable. |

### P2: Filesystem Semantics

| Work Item | Why It Matters | Target Outcome |
|-----------|----------------|----------------|
| POSIX metadata gates | File/copy/backup/stat may expose mode/owner/group values that do not exist on Windows. | Metadata fields are nullable or capability-gated. |
| Symlink policy by target | Windows symlinks may require privileges/developer mode and PowerShell semantics. | `symlink` reports clear unsupported/permission errors and has Windows fixtures. |
| Controller vs target path typing | Some paths are controller paths, some are target paths, and some are virtual MemoryFileSystem paths. | APIs and docs distinguish controller paths from target paths. |
| CRLF/newline fixtures | Text editing blocks need predictable behavior on Windows checkouts. | `lineinfile`, `blockinfile`, `replace`, `template`, and `file` have CRLF tests. |
| Fetch semantics | `fetch` crosses target-to-controller boundaries and can blur FileSystem ownership. | Explicit tests for local, SSH-to-Linux, and Windows target fetch. |

### P2: Network, Transfer, And Audit

| Work Item | Why It Matters | Target Outcome |
|-----------|----------------|----------------|
| Target/controller transfer mode docs | `download` supports target and controller paths, but users need clear behavior. | Document `auto`, `remote`, and `controller` modes and when fallback is allowed. |
| Windows network fixtures | PowerShell strategies exist but need proof. | Windows tests for URI, download, DNS, TCP, and ping. |
| FreeBSD network tool probes | Tool flags differ across BSD utilities. | Capability detection covers BSD `ping`, `nc`, DNS, and checksum tools. |
| Audit every execution path | Shell audit logging covers `ExecutionService`; direct local `Process.run` gaps may remain. | No block bypasses `ExecutionService` unless intentionally controller-side and documented. |
| PowerShell audit readability | Encoded commands should be decoded in logs. | Audit records always include readable command text plus redacted env/stdout/stderr. |

### P3: OS, Package, Firewall, And Container Blocks

| Work Item | Why It Matters | Target Outcome |
|-----------|----------------|----------------|
| Linux-only blocks declare Linux-only | Blocks like `systemd`, `ufw`, `firewalld`, `alternatives`, and distro package managers should not imply portability. | Metadata and docs say exactly which Linux families/tools are supported. |
| Generic `package` dispatcher | The generic block should choose an available manager from target facts, not controller assumptions. | Dispatcher uses target capability probes and fails with manager suggestions. |
| Container block remote policy | Docker context may be local controller or target host; current remote-safety is unclear. | `container*` blocks document and test target Docker context behavior. |
| Rollback semantics for system blocks | Some OS blocks claim rollback but external state may be complex. | Rollback is either tested per platform or downgraded in the matrix. |

### P4: Documentation Debt

| Work Item | Why It Matters | Target Outcome |
|-----------|----------------|----------------|
| Align docs with code reality | Some block docs claim platform support that is currently stubbed or untested. | Every block doc has a verified support table and unsupported notes. |
| Add "new configs should use direct blocks" guidance everywhere resource/actions examples appear | `resource { actions { ... } }` remains common in old docs. | Resource/actions examples are marked legacy or converted to direct blocks. |
| Add unsupported-target examples | Users need to know what failure looks like. | Docs show example errors for Linux-only block on Windows/macOS/FreeBSD. |
| Document supported platform tiers | "Supported" should distinguish implemented, tested, and planned. | Docs use the same legend as this matrix. |

## Known Target Bugs (from API audit)

| File | Line | Issue | Fix |
|------|------|-------|-----|
| `dependency_block.dart` | 181–187 | `_pingArgs` macOS `-W` was in seconds (must be ms) | Fixed — `'macos'` branch uses `timeoutSeconds * 1000` |
| `dependency_block.dart` | 228 | `Socket.connect(...)` → use `networkService.probeTcp()` | Fixed |
| `wait_for_block.dart` | 156 | `Socket.connect(...)` → use `networkService.probeTcp()` | Fixed |
| `wait_for_block.dart` | 175–180 | `_pingArgs` macOS `-W` was in seconds (must be ms) | Fixed — `'macos'` branch uses `timeoutSeconds * 1000` |
| `ssh_execution_service.dart` | 57 | POSIX FFI bindings loaded `libc.so.6` during Windows import | Fixed — Windows import does not initialize POSIX bindings |
| `lua_library.dart` | 100–102 | Local Lua `runCommand()` failed without a remote process backend | Fixed — local fallback uses the platform shell |
| `network_strategy.dart` | 164–170 | Unix ping host was shell-quoted but passed as a direct process arg | Fixed — Unix ping probe now goes through `sh -c` |
| `v2_apply.dart` / `action_block.dart` | processor errors | `--fail-fast` recorded errors but the processor could continue walking later elements | Fixed — processor error handler can halt at first processor/block error |
| `.github/workflows/release.yml` | build command | Release compile command lost a line continuation before build metadata flags | Fixed |
| `systemd_block.dart` | 610-611 | `Directory.systemTemp` + `File()` → use `fileSystem` | Replace with file system abstraction |
| `system_info.dart` | 85 | `tempdir` uses `Directory.systemTemp.path` — backslash on Windows | Fixed — added `tempdir_uri` with forward slashes |
| `lua_fixture_runner.dart` | 167–193 | `os.execute('mkdir -p')` / `os.execute('rm -rf')` in Lua scripts | Fixed — added `makeDir()`/`removeTree()` helpers |
| `sweep_test.dart` | 67 | `effectiveConfig` redundant alias | Fixed |
| `sweep_test.dart` | 104–115 | Duplicated lockfile teardown | Fixed — consolidated into single `tearDown` |
| `generate_metadata.dart` | 18 | Import from `test/` directory | Fixed — moved `FixtureAssertionLibrary` to `lib/src/lua/` |
| `secrets_redaction_test/config` | 2 | `file://$tempdir` — backslash broken on Windows | Fixed — uses `$tempdir_uri` (forward slashes) |

## Portability Capability Names

These names should become the common vocabulary for block metadata, unsupported-target errors, CI tags, and docs.

| Capability | Meaning | Probe |
|------------|---------|-------|
| `fs.read` | Target filesystem can read files | `FileSystem.file(path).exists/read` |
| `fs.write` | Target filesystem can write files | `FileSystem.file(path).write` |
| `fs.symlink` | Target filesystem supports symlinks | Create/read test symlink or target facts |
| `fs.posix_permissions` | Target supports POSIX mode bits, owner, group | target family is POSIX and tool probes pass |
| `exec.process` | Target can execute commands | `ExecutionService.run` |
| `exec.sh` | Target has POSIX `sh` | `command -v sh` |
| `exec.bash` | Target has Bash | `command -v bash` |
| `exec.powershell` | Target has PowerShell | `pwsh -NoProfile -Command` or `powershell.exe` |
| `net.http_client` | Target can perform HTTP requests from its own network namespace | `curl`, `wget`, or PowerShell web request |
| `net.tcp_probe` | Target can probe TCP sockets | Dart local socket, `nc`, Bash `/dev/tcp`, or PowerShell TCP client |
| `archive.tar` | Target can read/write tar archives | `tar --version` or `tar --help` |
| `archive.zip` | Target can read/write zip archives | `unzip`/`zip` or PowerShell archive cmdlets |
| `os.systemd` | Target has systemd | `systemctl --version` |
| `os.launchd` | Target has launchd | macOS target facts plus `launchctl` |
| `os.windows_service` | Target has Windows service APIs | PowerShell service cmdlets |
| `pkg.apt` | Target has apt | `command -v apt-get` |
| `pkg.dnf` | Target has dnf | `command -v dnf` |
| `pkg.yum` | Target has yum | `command -v yum` |
| `pkg.pacman` | Target has pacman | `command -v pacman` |
| `pkg.apk` | Target has apk | `command -v apk` |
| `pkg.brew` | Target has Homebrew | `command -v brew` |
| `pkg.winget` | Target has winget | PowerShell `Get-Command winget` |
| `fw.ufw` | Target has UFW | `command -v ufw` |
| `fw.firewalld` | Target has firewalld | `command -v firewall-cmd` |
| `container.docker` | Target has Docker CLI/daemon | `docker info` |

## Detailed Portability Backlog

### Tier 0: Test Harness And Path Hygiene

These are not block features, but they gate all Windows/macOS work.

| Item | Status | Required Change | Validation |
|------|--------|-----------------|------------|
| Windows path separator leakage in MemoryFileSystem tests | In progress | Use `path.posix` or `fileSystem.path` for internal virtual paths; `fetch`, `rename`, `sync`, and `symlink` have targeted fixes | Run unit tests on Windows |
| Recursive directory copy preserves layout | In progress | Copy files by `relative(entity.path, from: source)` instead of basename-only recursion | `copy`, `backup`, and file-service tests |
| `generate_keys.sh` CRLF sensitivity | Needs guard | Enforce LF in repo and/or generate keys from Dart test setup | Docker SSH integration on Windows checkout |
| Lua plugin default process behavior | Fixed for Configr API | `runCommand()` uses the injected backend for remote applies and local shell fallback for local applies | `sftp_filesystem_test.dart` on Windows |
| Sweep fixture shell dependence | Not started | Add Lua fixture runner and migrate portable fixtures | Portable sweep on Linux/macOS/Windows |
| Unit/integration test partitioning | Partial | Directory-specific CI commands plus test tags | CI unit jobs do not run container/sweep tests |

### Tier 1: Filesystem Blocks

Goal: run from local controller, SSH-to-Linux, macOS local, and Windows local where filesystem semantics exist. Remote Windows support depends on a Windows transport decision.

| Block | Current Risk | Strategy | Required Capabilities | Next Tests |
|-------|--------------|----------|-----------------------|------------|
| `file` | POSIX permissions may not map to Windows | Keep core read/write portable; gate owner/group/mode behind `fs.posix_permissions` | `fs.read`, `fs.write` | Lua sweep create/update/delete |
| `copy` | Separator and recursive layout bugs on Windows | Use target `FileSystem`; preserve relative paths with POSIX virtual paths in MemoryFileSystem | `fs.read`, `fs.write` | Unit test nested recursive copy |
| `delete` | Mostly portable | Use target `FileSystem`; confirm directory recursion on SFTP | `fs.write` | Lua sweep file and directory delete |
| `move` | Mostly portable | Use target `FileSystem`; define overwrite semantics | `fs.read`, `fs.write` | Lua sweep move with rollback |
| `rename` | POSIX-style target paths now normalize Windows separators | Keep using `path.posix` for virtual paths until target path typing exists | `fs.read`, `fs.write` | Windows unit test for basename/dirname |
| `touch` | Mostly portable | Use target `FileSystem`; avoid chmod assumptions | `fs.write` | Lua sweep |
| `backup` | Directory entries were copied as files; path separator risk | Filter files, preserve relative paths, gate metadata | `fs.read`, `fs.write` | Unit test nested directory backup |
| `lineinfile` | Mostly portable | Confirm newline handling and encoding on Windows | `fs.read`, `fs.write` | Lua sweep with CRLF fixture |
| `blockinfile` | Mostly portable | Confirm marker/newline behavior on Windows | `fs.read`, `fs.write` | Lua sweep with CRLF fixture |
| `replace` | Mostly portable | Confirm regex/newline behavior on Windows | `fs.read`, `fs.write` | Lua sweep |
| `template` | Portable if template source is controller-side by design | Clarify controller template read vs target destination write | `fs.write` | Lua sweep rendered output |
| `stat` | POSIX mode/owner fields are platform-specific | Return nullable/unsupported metadata fields on Windows | `fs.read` | Windows unit test |
| `slurp` | Portable | Use target `FileSystem` only | `fs.read` | Lua sweep |
| `fetch` | Semantics need target->controller clarity; path construction now normalizes raw Windows separators | For SSH, read from target FS and write to controller; for local, normal copy | `fs.read` plus controller write | Integration fixture with remote SSH |

### Tier 2: Execution, Hooks, And Plugins

Goal: every process call goes through the target `ExecutionService`, and every Lua call receives the target file/process adapters.

| Surface | Current Risk | Strategy | Required Capabilities | Next Tests |
|---------|--------------|----------|-----------------------|------------|
| `execute` | Shell strategy implemented: `shell` property accepts `sh`, `bash`, `powershell`; defaults to `sh` | Uses `ShellType` to resolve executable and `-c` args; `capabilities.dart` defines `exec.sh`, `exec.bash`, `exec.powershell` | `exec.sh`, `exec.bash`, `exec.powershell` | Unit tests for shell property parsing; local smoke with fake backend |
| `raw` | No longer double-shelled; uses `executionService.run()` directly; `stdin` now wired; exit code checked | Execute through target backend with configurable executable | `exec.process` | Unit test exit-code handling; local smoke |
| `script` | Double-shelling fixed — runs script directly via `privilegeEscalation.runWithElevatedPrivileges` with `runInShell: false` | Copy script to target temp dir, `chmod +x`, run with no outer shell wrapper | `fs.write`, `exec.process` | SSH integration script fixture |
| Bash hooks | `TargetSystemProbe` now probes `hasBash` on target | Copy to target and require `exec.bash`; fail clearly on Windows | `fs.write`, `exec.bash` | SSH hook integration |
| Lua hooks | Target facts available; backend injection is complete | Ensure file/process APIs use target adapters | `fs.read`, `fs.write`; optional `exec.process` | Lua hook writes file on SSH target |
| Lua plugins | File/process APIs are target-aware; context uses target facts | SystemInfo now accepts TargetSystemFacts; applyV2 probes target before plugin init | `fs.read`, `fs.write`; optional `exec.process` | Plugin target-facts test |
| `git` | Requires git and network from target | Use target `ExecutionService`; probe `git`; document controller fallback if added | `exec.process`, `net.http_client` | SSH target clone fixture |

### Tier 3: Network And Transfer Blocks

Goal: target-side network by default, with explicit controller relay when the target cannot or should not download directly.

| Block | Default Mode | Controller Relay Mode | Required Capabilities | Progress Strategy |
|-------|--------------|-----------------------|-----------------------|-------------------|
| `download` | Target downloads directly to target destination | Controller streams to cache, then copies over target FS | `net.http_client`, `fs.write` | Tool progress parsing or temp status file |
| `uri` | Target makes HTTP request | Controller makes HTTP request only if explicitly requested | `net.http_client` | Response metadata only |
| `network` | Target checks its own interface/routing state | No relay, because controller view is wrong | platform strategy | Command output parsing |
| `wait_for` | Target probes host/port/path from target network namespace | Controller probe only if configured | `net.tcp_probe` or `exec.process` | Poll attempt events |
| `dependency` | Target validates dependency reachability | Controller validation only for controller dependencies | `net.tcp_probe`, `exec.process` | Poll attempt events |

Decision needed: name the transfer mode. Candidate values:

- `transfer_mode = "target"`: default for remote targets; target performs network call.
- `transfer_mode = "controller"`: controller downloads/requests and then copies or returns data.
- `transfer_mode = "auto"`: prefer target, fall back to controller only when explicitly allowed by `allow_controller_fallback = true`.

### Tier 4: Archive Blocks

| Block | Portable Core | Platform Strategy | Open Decision |
|-------|---------------|-------------------|---------------|
| `unarchive` | File placement through target FS | POSIX `tar`/`unzip`; Windows PowerShell `Expand-Archive` | Should tar.gz on Windows require bundled Dart archive support or external tools? |
| `compress` | Could be Dart-native for local/controller archives | POSIX `tar`/`zip`; Windows `Compress-Archive` | Should remote compression be target-side by default? |
| `decompress` | Could be Dart-native for local/controller archives | POSIX tools; Windows PowerShell | Align behavior with `unarchive` or merge concepts later |

### Tier 5: OS Management Blocks

| Block | Linux Strategy | macOS Strategy | Windows Strategy | Policy |
|-------|----------------|----------------|------------------|--------|
| `service` | `systemctl`, fallback init providers later | `launchctl` | PowerShell service cmdlets | Generic block with platform strategies |
| `systemd` | `systemctl` only | Unsupported | Unsupported | Linux/systemd-only |
| `user` | `useradd/usermod/userdel` | `dscl` | PowerShell local user cmdlets | Generic block with platform strategies |
| `group` | `groupadd/groupmod/groupdel` | `dseditgroup`/`dscl` | PowerShell local group cmdlets | Generic block with platform strategies |
| `hostname` | `hostnamectl`, fallback `/etc/hostname` | `scutil` | `Rename-Computer` | Generic block with platform strategies |
| `timezone` | `timedatectl` or distro files | `systemsetup` | `tzutil` | Generic block with platform strategies |
| `locale_gen` | Debian/Ubuntu locale generation | Unsupported | Unsupported | Linux-only, possibly distro-specific |
| `sysctl` | `/proc/sys` and `sysctl` | Limited sysctl read/write, not same persistence | Unsupported | Declare Linux-only until macOS semantics are designed |
| `cron` | crontab | crontab or launchd | Task Scheduler | Generic scheduler abstraction may be better |
| `alternatives` | `update-alternatives` | Unsupported | Unsupported | Linux-only |
| `mount` | `mount`, `/etc/fstab` | `mount`, `/etc/fstab` semantics differ | PowerShell/storage APIs | Split strategy; destructive tests opt-in |
| `authorized_key` | OpenSSH file layout | OpenSSH file layout | Windows OpenSSH layout varies | File strategy plus OS-specific home lookup |
| `known_hosts` | OpenSSH file layout | OpenSSH file layout | Windows OpenSSH layout varies | File strategy plus OS-specific home lookup |
| `permissions` | chmod/chown | chmod/chown | ACL APIs | POSIX now; Windows ACL later |

### Tier 6: Package, Firewall, And Container Blocks

| Block | Platform Policy | Required Capabilities | Test Policy |
|-------|-----------------|-----------------------|-------------|
| `apt` | Debian/Ubuntu only | `pkg.apt` | Debian/Ubuntu containers only |
| `dnf` | Fedora/RHEL family only | `pkg.dnf` | Fedora container only |
| `yum` | Legacy RHEL family only | `pkg.yum` | RHEL-compatible container when available |
| `pacman` | Arch only | `pkg.pacman` | Arch container only |
| `apk` | Alpine only | `pkg.apk` | Alpine container only |
| `brew` | macOS or Linuxbrew when installed | `pkg.brew` | macOS optional, Linuxbrew optional |
| `package` | Fact/capability dispatcher | one package capability | Unit strategy tests plus distro containers |
| `ufw` | UFW only | `fw.ufw` | Ubuntu container or privileged opt-in |
| `firewalld` | firewalld only | `fw.firewalld` | Fedora/RHEL privileged opt-in |
| `container` | Target must own Docker context | `container.docker` | Do not run by default on macOS/Windows public CI |
| `container_exec` | Target Docker context | `container.docker` | Same as `container` |
| `container_logs` | Target Docker context | `container.docker` | Same as `container` |

## Audit Queue

This queue is a concrete search list for the next implementation pass.

| Area | Files To Inspect First | Why |
|------|------------------------|-----|
| Hook staging | `lib/src/hooks/hook_manager.dart` | Bash hooks are staged through `ExecutionService`; `TargetSystemProbe.hasBash` provides capability data; fail clearly on Windows when bash absent |
| Plugin facts | `lib/src/plugins/plugin_context.dart`, `lib/src/plugins/lua_library.dart` | Lua context now reads processor facts from target-derived SystemInfo; `fromConfigContext` reads target-correct `os.family`, `os.distribution`, `os.distributionVersion`, `os.kernel` |
| File utilities | `lib/src/utils/file_utils.dart`, `lib/src/utils/file_service.dart` | Still contains controller process calls for chmod/chown/stat/executable checks |
| Target facts | `lib/src/utils/platform.dart`, `lib/src/utils/system_info.dart`, `lib/src/utils/target_system.dart` | SystemInfo now accepts `TargetSystemFacts?` — `applyV2` probes target before plugin init and block processing; `TargetSystemFacts` extended with `kernel` and `fqdn` |
| Network runtime | `lib/src/utils/network_service.dart`, `lib/src/strategies/network_strategy.dart` | Windows PowerShell strategy exists; needs fixture coverage and clearer target/controller transfer docs |
| Multi-host dependency checks | `lib/src/multi_host/dependency_checker.dart` | Uses direct ping/socket from controller |
| OS blocks | `service`, `user`, `group`, `hostname`, `timezone`, `systemd` | Need strategy registry and unsupported errors |
| Path joins | `v2_apply` plus remaining block-specific path math | `fetch`, `rename`, `sync`, and `symlink` now use normalized POSIX or target `FileSystem` paths; keep auditing controller paths vs target virtual paths |
