# Block Portability Matrix

**Date:** 2026-06-30  
**Legend:** ✅ yes | 🔶 partial | ❌ no | ➖ n/a | ❓ unknown

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
| download | ✅ | ✅ | ❓ | ✅ | ✅ | via NetworkService | Windows: needs PowerShell/curl strategy |
| uri | ✅ | ✅ | ❓ | ✅ | ✅ | via NetworkService | Windows: needs PowerShell/curl strategy |
| network | ✅ | ✅ | ❓ | ✅ | ❌ | via NetworkService | Windows: needs PowerShell strategy |
| wait_for | ✅ | ✅ | ✅ | ✅ | ❌ | `networkService.probeTcp` / `ExecutionService.run` | macOS/Linux ping fixed, Windows ping via `-n -w` |
| unarchive | ✅ | ✅ | ❓ | ✅ | ❌ | via ExecutionService | |
| compress | ✅ | ✅ | ❓ | ❌ | ❌ | via ExecutionService | |
| decompress | ✅ | ✅ | ❓ | ❌ | ❌ | via ExecutionService | |
| script | ✅ | ✅ | ❓ | ✅ | ❌ | ✅ | Windows: needs PowerShell strategy |
| execute | ✅ | ✅ | ❓ | ✅ | ❌ | ✅ | |
| raw | ✅ | ✅ | ❓ | ✅ | ❌ | via ExecutionService | |
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

## Known Target Bugs (from API audit)

| File | Line | Issue | Fix |
|------|------|-------|-----|
| `dependency_block.dart` | 181–187 | `_pingArgs` macOS `-W` was in seconds (must be ms) | Fixed — `'macos'` branch uses `timeoutSeconds * 1000` |
| `dependency_block.dart` | 228 | `Socket.connect(...)` → use `networkService.probeTcp()` | Fixed |
| `wait_for_block.dart` | 156 | `Socket.connect(...)` → use `networkService.probeTcp()` | Fixed |
| `wait_for_block.dart` | 175–180 | `_pingArgs` macOS `-W` was in seconds (must be ms) | Fixed — `'macos'` branch uses `timeoutSeconds * 1000` |
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
| Lua plugin default process hang on Windows | Fixed for Configr API | `runCommand()` now requires an injected process backend; file-only plugins still run without one | `sftp_filesystem_test.dart` on Windows |
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
| `execute` | Inherits controller env; shell behavior varies | Add shell strategy: POSIX `sh`, Bash optional, PowerShell on Windows | `exec.process`; optional `exec.sh`/`exec.powershell` | Pure unit fake backend plus local smoke |
| `raw` | Command string may assume POSIX shell | Execute exactly through target backend; require target family or shell selector | `exec.process` | Fake backend test |
| `script` | Local scripts must be copied before remote execution | Copy script to target temp dir, run with selected interpreter, cleanup | `fs.write`, `exec.process` | SSH integration script fixture |
| Bash hooks | POSIX-only; remote staging now uses target temp allocation | Copy to target and require `exec.bash`; fail clearly on Windows | `fs.write`, `exec.bash` | SSH hook integration |
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
| Hook staging | `lib/src/hooks/hook_manager.dart` | Bash hooks are staged through `ExecutionService`; remaining work is capability probing for `exec.bash` |
| Plugin facts | `lib/src/plugins/plugin_context.dart`, `lib/src/plugins/lua_library.dart` | Lua context now reads processor facts from target-derived SystemInfo; `fromConfigContext` reads target-correct `os.family`, `os.distribution`, `os.distributionVersion`, `os.kernel` |
| File utilities | `lib/src/utils/file_utils.dart`, `lib/src/utils/file_service.dart` | Still contains controller process calls for chmod/chown/stat/executable checks |
| Target facts | `lib/src/utils/platform.dart`, `lib/src/utils/system_info.dart`, `lib/src/utils/target_system.dart` | SystemInfo now accepts `TargetSystemFacts?` — `applyV2` probes target before plugin init and block processing; `TargetSystemFacts` extended with `kernel` and `fqdn` |
| Network runtime | `lib/src/utils/network_service.dart` | Needs complete target/controller split and Windows PowerShell backend |
| Multi-host dependency checks | `lib/src/multi_host/dependency_checker.dart` | Uses direct ping/socket from controller |
| OS blocks | `service`, `user`, `group`, `hostname`, `timezone`, `systemd` | Need strategy registry and unsupported errors |
| Path joins | `v2_apply` plus remaining block-specific path math | `fetch`, `rename`, `sync`, and `symlink` now use normalized POSIX or target `FileSystem` paths; keep auditing controller paths vs target virtual paths |
