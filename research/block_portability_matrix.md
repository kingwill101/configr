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
| wait_for | ✅ | ✅ | ❓ | ✅ | ❌ | ❌ `Socket.connect` | Has target-bug (direct Socket) |
| unarchive | ✅ | ✅ | ❓ | ✅ | ❌ | via ExecutionService | |
| compress | ✅ | ✅ | ❓ | ❌ | ❌ | via ExecutionService | |
| decompress | ✅ | ✅ | ❓ | ❌ | ❌ | via ExecutionService | |
| script | ✅ | ✅ | ❓ | ✅ | ❌ | ✅ | Windows: needs PowerShell strategy |
| execute | ✅ | ✅ | ❓ | ✅ | ❌ | ✅ | |
| raw | ✅ | ✅ | ❓ | ✅ | ❌ | via ExecutionService | |
| git | ✅ | ✅ | ❓ | ✅ | ❌ | via ExecutionService | |
| dependency | ✅ | ✅ | ❓ | ✅ | ❌ | ❌ `Process.run`+`Socket` | Has target-bugs (direct dart:io) |
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
| B: Process/Network | 12 | 12 | 12 | 0 | 10 | 3 |
| C: OS Management | 14 | 14 | 5 | 0 | 14 | 10 |
| D: Platform-specific | 9 | 8 | 1 | 0 | 9 | 7 |
| E: Control/Meta | 14 | 14 | 14 | 13 | 12 | 0 |
| **Total** | **63** | **62** | **46** | **24** | **59** | **34** |

## Known Target Bugs (from API audit)

| File | Line | Issue | Fix |
|------|------|-------|-----|
| `dependency_block.dart` | 187, 209 | `Process.run('ping', ...)` → use `executionService.run()` | Replace with execution service |
| `dependency_block.dart` | 228 | `Socket.connect(...)` → use `networkService.probeTcp()` | Replace with network service |
| `wait_for_block.dart` | 156 | `Socket.connect(...)` → use `networkService.probeTcp()` | Replace with network service |
| `systemd_block.dart` | 610-611 | `Directory.systemTemp` + `File()` → use `fileSystem` | Replace with file system abstraction |
