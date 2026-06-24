# Configr Roadmap: Ansible-Inspired Module Expansion & Container Testing

## 1. Current State

31 action blocks implemented across 6 categories. See [docs/index.md](docs/index.md) for the full list.

### Notable gaps vs Ansible builtin modules

| Category | Configr Status | Ansible Comparison |
|----------|---------------|-------------------|
| File operations (copy, move, delete, symlink, touch) | ✅ Full coverage | On par with `ansible.builtin.{copy,file}` |
| File content editing (create, append, prepend, replace) | ✅ Full | Has `file { create/edit }` + `lineinfile`, `blockinfile`, `replace` blocks |
| Permissions (chmod, chown, ACL) | ✅ Full | On par with `ansible.builtin.file` + `ansible.posix.acl` |
| Templates (Liquid, Mustache) | ✅ Full | On par with `ansible.builtin.template` |
| Archives (compress/decompress/backup) | ✅ Full | Exceeds Ansible (`backup` with incremental, encryption) |
| Downloads | ✅ Full | On par with `ansible.builtin.get_url` |
| Sync (bidirectional) | ✅ Full | Exceeds Ansible's `synchronize` (bidirectional mode) |
| Validation (JSON/YAML schema, checksum) | ✅ Full | Unique to Configr |
| Shell execution | ✅ Full | On par with `ansible.builtin.shell/command` |
| Systemd | ✅ Full | On par with `ansible.builtin.systemd` |
| Network checks (HTTP/TCP/DNS/ping) | ✅ Full | Exceeds Ansible's `uri` (multiple check types) |
| Git (clone/pull/push/commit) | ✅ Full | On par with `ansible.builtin.git` |
| **Package managers (11)** | ✅ Full | On par with `ansible.builtin.{apt,yum,dnf,pacman,...}` |
| **Plugin system (Dart + Lua)** | ✅ Full | Unique to Configr |
| **User/group management** | ✅ Implemented | `ansible.builtin.{user,group}` — Linux full, macOS/FreeBSD stubs |
| **Regex file editing (lineinfile/blockinfile/replace)** | ✅ Implemented | `ansible.builtin.{lineinfile,blockinfile,replace}` — MemFS-testable |
| **System settings (hostname, timezone, sysctl, locale_gen)** | ✅ Implemented | `ansible.posix.{hostname,timezone,sysctl}`, `locale_gen` — multi-OS dispatch |
| **Alternatives** | ✅ Implemented | `community.general.alternatives` — Debian full, RHEL stub |
| **Assert** | ✅ Implemented | `ansible.builtin.assert` — shell condition testing |
| **Cron jobs** | ❌ Missing | `ansible.builtin.cron` |
| **Wait_for** | ❌ Missing | `ansible.builtin.wait_for` |
| **Firewall (ufw, firewalld)** | ❌ Missing | Plugin territory |
| **Mount** | ❌ Missing | Plugin territory |
| **SELinux** | ❌ Missing | Plugin territory |
| **Crypto (certificates, keys)** | ❌ Missing | Plugin territory |
| **Desktop/GUI (dconf, .desktop, fonts)** | ❌ Missing | Plugin territory |

---

## 2. Phase 1: Core Blocks (Out of the Box)

These directly map to common dotfiles/system-config tasks and should ship as built-in blocks.

### 2.1 `user` block ✅

Ansible equivalent: `ansible.builtin.user`

```configr
resource {
  type "user"
  name "john"
  state "present"

  actions {
    user {
      uid "1001"
      group "users"
      groups "wheel,docker"
      shell "/bin/zsh"
      home "/home/john"
      create_home "true"
    }
  }
}
```

Platform dispatch: `_LinuxUserBlock` (full), `_MacOSUserBlock` (stub), `_FreeBSDUserBlock` (stub)

### 2.2 `group` block ✅

Ansible equivalent: `ansible.builtin.group`

```configr
resource {
  type "group"
  name "mygroup"
  state "present"

  actions {
    group {
      gid "1002"
      system "false"
    }
  }
}
```

Platform dispatch: `_LinuxGroupBlock` (full), `_MacOSGroupBlock` (stub), `_FreeBSDGroupBlock` (stub)

### 2.3 `lineinfile` block ✅

```configr
resource {
  type "lineinfile"
  path "~/.bashrc"
  state "present"

  actions {
    lineinfile {
      regexp "^export EDITOR="
      line "export EDITOR=vim"
      insert_after "^# Aliases"
      backup "true"
      create "true"
    }
  }
}
```

### 2.4 `blockinfile` block ✅

```configr
resource {
  type "blockinfile"
  path "~/.ssh/config"
  state "present"

  actions {
    blockinfile {
      marker "# {mark} ANSIBLE MANAGED BLOCK"
      block """
Host github.com
  HostName github.com
  IdentityFile ~/.ssh/id_ed25519
"""
      backup "true"
      create "true"
    }
  }
}
```

### 2.5 `replace` block ✅

```configr
resource {
  type "replace"
  path "/etc/nginx/nginx.conf"
  state "present"

  actions {
    replace {
      regexp "worker_connections\\s+\\d+"
      replace "worker_connections 2048"
      backup "true"
      after "events\\s*\\{"
      before "}"
    }
  }
}
```

### 2.6 `hostname` block ✅

```configr
resource {
  type "hostname"
  name "my-machine"
  state "present"

  actions {
    hostname {
      use "systemd"
    }
  }
}
```

Platform dispatch + `use` strategy parameter (`systemd`/`file`/`generic`/`hostname`).

### 2.7 `timezone` block ✅

```configr
resource {
  type "timezone"
  name "America/New_York"
  state "present"

  actions {
    timezone {}
  }
}
```

Platform dispatch: `_LinuxTimezoneBlock` (timedatectl + /etc/localtime), macOS, FreeBSD

### 2.8 `sysctl` block ✅

```configr
resource {
  type "sysctl"
  name "net.ipv4.ip_forward"
  state "present"

  actions {
    sysctl {
      value "1"
      reload "true"
      sysctl_file "/etc/sysctl.d/99-custom.conf"
    }
  }
}
```

Platform dispatch: Linux (full), macOS (stub), FreeBSD (full), OpenBSD (full). Supports `state: absent`, `ignore_errors`, `sysctl_set`.

### 2.9 `cron` block ❌

```configr
cron {
  name = "daily backup"
  minute = "0"
  hour = "2"
  day = "*"
  month = "*"
  weekday = "*"
  job = "/usr/local/bin/backup.sh"
  state = "present"          # present | absent
  user = "root"
  cron_file = "backup"       # /etc/cron.d/backup
}
```

**Not yet implemented.**

### 2.10 `locale_gen` block ✅

```configr
resource {
  type "locale_gen"
  name "en_US.UTF-8"
  state "present"

  actions {
    locale_gen {}
  }
}
```

Supports single name or list (`locales`). Platform dispatch: Debian/Ubuntu (full), Arch Linux (full).

### 2.11 `alternatives` block ✅

```configr
resource {
  type "alternatives"
  name "editor"
  state "selected"

  actions {
    alternatives {
      path "/usr/bin/vim.basic"
      link "/usr/bin/editor"
      priority "50"
    }
  }
}
```

State enum: `present`, `selected`, `auto`, `absent`. Supports slave subcommands. Platform dispatch: Debian (full), RHEL (stub).

### 2.12 `assert` block ✅

```configr
resource {
  type "assert"
  state "present"

  actions {
    assert {
      condition "which docker"
      fail_msg "Docker is not installed"
      success_msg "Docker is available"
    }
  }
}
```

### 2.13 `wait_for` block ❌

```
wait_for {
  host = "localhost"
  port = 8080
  state = "started"          # started | stopped | drained
  delay = 5
  timeout = 60
  # OR for file-based:
  path = "/var/run/app.pid"
  search_regex = "\\d+"
}
```

**Not yet implemented.**

---

## 3. Phase 2: Addon/Plugin Modules

These are more specialized. Ship as separate packages or built-in plugins.

| Addon | Description | Ansible Inspiration |
|-------|-------------|-------------------|
| `configr-firewall` | ufw & firewalld management | `community.general.ufw`, `ansible.posix.firewalld` |
| `configr-mount` | Mount filesystems (fstab) | `ansible.posix.mount` |
| `configr-selinux` | SELinux context, boolean, port | `ansible.posix.selinux` |
| `configr-crypto` | OpenSSL certs, keys, CSRs | `community.crypto.openssl_*` |
| `configr-acme` | Let's Encrypt certificate management | `community.crypto.acme_certificate` |
| `configr-dconf` | GNOME/desktop settings via dconf | `community.general.dconf` |
| `configr-desktop-entry` | Create .desktop files | — |
| `configr-font` | Font installation & management | — |
| `configr-vscode` | VS Code extension management | — |
| `configr-ssh` | SSH key generation, known_hosts | `community.crypto.openssh_keypair`, `known_hosts` |
| `configr-gpg` | GPG key management | `community.general.gpg_key` |
| `configr-git-config` | Git config management | `community.general.git_config` |
| `configr-docker-compose` | Docker Compose management | `community.docker.docker_compose` |
| `configr-podman` | Podman container management | `containers.podman` |

---

## 4. Docs

| Doc | Status | Notes |
|-----|--------|-------|
| `docs/index.md` | ✅ | Full table with all 33 blocks |
| `docs/modules/user-module.md` | ✅ | New — user management docs |
| `docs/modules/group-module.md` | ✅ | New — group management docs |
| `docs/modules/hostname-module.md` | ✅ | New — hostname with `use` strategy |
| `docs/modules/timezone-module.md` | ✅ | New — timezone with validation |
| `docs/modules/sysctl-module.md` | ✅ | New — sysctl with state=absent |
| `docs/modules/alternatives-module.md` | ✅ | New — alternatives with state enum |
| `docs/modules/locale_gen-module.md` | ✅ | New — locale_gen with list support |
| `docs/modules/lineinfile-module.md` | ✅ | New — regex line editing |
| `docs/modules/blockinfile-module.md` | ✅ | New — marker-based block management |
| `docs/modules/replace-module.md` | ✅ | New — regex search/replace |
| `docs/modules/assert-module.md` | ✅ | New — shell condition testing |
| `docs/echo.md` | ✅ | Existing |
| `docs/file.md` | ✅ | Existing |
| `docs/git.md` | ✅ | Existing |
| `docs/network.md` | ✅ | Existing |
| `docs/systemd.md` | ✅ | Existing |
| Remaining top-level docs | ⬜ v1 syntax | `backup.md`, `compress.md`, `decompress.md`, `delete.md`, `execute.md`, `move.md`, `package.md`, `permissions.md`, `rename.md`, `symlink.md`, `sync.md`, `template.md`, `touch.md`, `validate.md` — still show nested `resource { actions { ... } }` v1 syntax. |

---

## 5. Container-Based Testing Solution

### 5.1 Problem

Many blocks (package managers, systemd, user/group, hostname, timezone, etc.)
cannot be tested with the existing in-memory filesystem approach. They need
real environments with specific distros and installed tools.

### 5.2 Architecture

```
test/container/
├── helpers/
│   └── configr_test_utils.dart # Shared: configrApply, assertIdempotent, shell
├── user_integration_test.dart
├── group_integration_test.dart
├── hostname_integration_test.dart
├── timezone_integration_test.dart
├── sysctl_integration_test.dart
├── locale_gen_integration_test.dart
├── alternatives_integration_test.dart
├── cron_integration_test.dart
├── wait_for_integration_test.dart
├── apt_block_integration_test.dart   # Docker-in-Docker (testcontainers_core)
├── container_test_helper.dart        # Docker-in-Docker helper
└── container_test_runner.dart        # Tag constants (debianTag, needsRootTag)

testing/
├── containers/
│   ├── ubuntu/
│   │   └── Dockerfile          # Ubuntu 24.04 with systemd + Dart SDK
│   ├── debian/
│   │   └── Dockerfile          # Debian bookworm with systemd + Dart SDK
│   ├── fedora/
│   │   └── Dockerfile          # Fedora 40 with systemd + Dart SDK
│   ├── arch/
│   │   └── Dockerfile          # Arch Linux with systemd + Dart SDK
│   └── alpine/
│       └── Dockerfile          # Alpine 3.20 for musl compatibility
├── scripts/
│   ├── run-all.sh              # Run tests across all distros sequentially
│   ├── run-distro.sh           # Run tests on a specific distro
│   └── ci-run.sh               # CI-optimized runner (env-based tag selection)
├── docker-compose.yml          # Container matrix (5 services with profiles)
└── README.md
```

### 5.3 Docker Image Design

Each distro image:

```
FROM <distro>:<tag>

# Install Dart SDK
RUN apt/apt-get/pacman/etc ...

# Install tools needed by various blocks
RUN install \
  apt dpkg          # For apt block testing
  systemctl         # For systemd block testing
  useradd/groupadd  # For user/group block testing
  chronyd/timedatectl # For timezone block testing
  hostnamectl       # For hostname block testing
  sysctl            # For sysctl block testing
  crond             # For cron block testing
  locale-gen        # For locale_gen block testing
  alternatives      # For alternatives block testing

# Copy configr source
WORKDIR /app
COPY . .

# Default: run tests
CMD ["dart", "test"]
```

### 5.4 Test Tagging Strategy

Use Dart's custom tags to route tests to the right container. See `dart_test.yaml`
for the full tag definition:

| Tag | Description |
|-----|-------------|
| `debian` | Debian/Ubuntu environment required |
| `fedora` | Fedora/RHEL environment required |
| `arch` | Arch Linux environment required |
| `alpine` | Alpine Linux environment required |
| `needs-systemd` | Requires privileged container with systemd |
| `needs-root` | Requires root privileges (useradd, groupdel, etc.) |
| `needs-docker` | Requires Docker socket access (Docker-in-Docker) |
| `destructive` | Modifies system state, run in isolation |
| `container` | Docker-in-Docker tests (uses testcontainers_core) |

Tests use multi-tag arrays for cross-distro compatibility:

```dart
test('creates a user and is idempotent', () async {
  final first = await configrApply(config);
  expect(first.isSuccess, isTrue);
  final second = await configrApply(config);
  expect(second.isChanged, isFalse);
}, tags: ['debian', 'fedora', 'arch', 'alpine', 'needs-root']);
```

### 5.5 Test Patterns (Ansible-Style)

Three patterns are used, inspired by Ansible's integration test methodology:

**1. Idempotency** — every test runs the config twice and asserts the second
   run produces no changes. Use `assertIdempotent()` from shared utils.

**2. Check-mode / dry-run** — `configrApply(config, dryRun: true)` verifies
   output without modifying state. Use `assertCheckMode()`.

**3. Clean-state** — each test cleans up in `teardown`/`finally` blocks.
   Tests are independently runnable.

**4. Distro-specific tests** — tagged by distro; some tests only run on
   `debian` (alternatives, locale_gen) or `needs-systemd` (hostname, timezone).

### 5.6 Test Runner Scripts

```bash
# Run all distro tests sequentially
testing/scripts/run-all.sh

# Run specific distro
testing/scripts/run-distro.sh ubuntu
testing/scripts/run-distro.sh fedora

# CI-optimized run
CONFIGR_TEST_ENV=ubuntu ./testing/scripts/ci-run.sh
```

### 5.7 Test Coverage by Environment

| Block | MemFS (unit) | Ubuntu | Debian | Fedora | Arch | Alpine |
|-------|:---:|:------:|:------:|:------:|:----:|:------:|
| copy, move, rename, touch | ✅ | — | — | — | — | — |
| delete, symlink, permissions | ✅ | — | — | — | — | — |
| compress, decompress | ✅ | — | — | — | — | — |
| backup | ✅ | — | — | — | — | — |
| validate | ✅ | — | — | — | — | — |
| template | ✅ | — | — | — | — | — |
| sync | ✅ | — | — | — | — | — |
| lineinfile, blockinfile, replace, assert | ✅ | — | — | — | — | — |
| execute | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| download | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| network | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| echo | ✅ | — | — | — | — | — |
| git | — | ✅ | ✅ | ✅ | ✅ | ✅ |
| systemd | — | ✅ | ✅ | ✅ | ✅ | ❌ |
| user | — | ✅ | ✅ | ✅ | ✅ | ✅ |
| group | — | ✅ | ✅ | ✅ | ✅ | ✅ |
| hostname | — | ✅ | ✅ | ✅ | ✅ | ✅ |
| timezone | — | ✅ | ✅ | ✅ | ✅ | ✅ |
| sysctl | — | ✅ | ✅ | ✅ | ✅ | ✅ |
| locale_gen | — | ✅ | ✅ | — | — | — |
| alternatives | — | ✅ | ✅ | ✅ | ✅ | — |
| apt | — | ✅ | ✅ | — | — | — |
| brew | — | — | — | — | — | — |
| dnf | — | — | — | ✅ | — | — |
| yum | — | — | — | — | — | — |
| pacman | — | — | — | — | ✅ | — |
| pamac | — | — | — | — | — | — |
| snap | — | ✅ | — | — | — | — |
| flatpak | — | ✅ | ✅ | ✅ | ✅ | — |
| docker | — | ✅ | ✅ | ✅ | ✅ | ✅ |
| npm | — | ✅ | ✅ | ✅ | ✅ | ✅ |
| pip | — | ✅ | ✅ | ✅ | ✅ | ✅ |
| cron | — | ✅ | ✅ | ✅ | ✅ | ✅ |
| wait_for | — | ✅ | ✅ | ✅ | ✅ | ✅ |

### 5.8 Implementation Steps

1. Create `testing/containers/base/Dockerfile` — Dart SDK + common dependencies
2. Create per-distro Dockerfiles inheriting from base
3. Create `testing/docker-compose.yml` with all distro services
4. Create `testing/scripts/run-distro.sh` — wrapper for single-distro runs
5. Create `testing/scripts/run-all.sh` — parallel matrix runner
6. Add `--tags` support in existing test files for environment-specific tests
7. Update CI workflow to include container matrix step
8. Document in `testing/README.md`

---

## 6. Implementation Order

```
Phase 1a — Foundation                  ✅ done
├── Missing docs                      ✅ 16 module docs created
├── Example configs                   ✅ lineinfile, blockinfile, replace, assert
└── Ansible source audit              ✅ 7 modules audited upstream

Phase 1b — Core Blocks                ✅ done
├── lineinfile block                  ✅
├── blockinfile block                 ✅
├── replace block                     ✅
├── user block                        ✅ (Ansible subclass pattern)
├── group block                       ✅ (Ansible subclass pattern)
├── assert block                      ✅
├── wait_for block                    ✅
└── cron block                        ✅

Phase 1c — System Blocks              ✅ done
├── hostname block                    ✅ (use strategy, current/permanent)
├── timezone block                    ✅ (multi-OS dispatch)
├── sysctl block                      ✅ (state=absent, FreeBSD/OpenBSD)
├── locale_gen block                  ✅ (list input, Arch Linux)
└── alternatives block                ✅ (state enum, subcommands)

Phase 1d — Container Testing          ✅ done
├── Dockerfiles (5 per-distro)
├── docker-compose.yml with 5 services + profiles
├── Tag system in dart_test.yaml (9 tags)
├── Test utilities (configr_test_utils.dart)
├── 9 integration test files (user, group, hostname, timezone, sysctl,
│   locale_gen, alternatives, cron, wait_for)
├── 3 runner scripts (run-distro.sh, run-all.sh, ci-run.sh)
└── testing/README.md

Phase 1e — Remaining Core Blocks      ✅ done
├── cron block                        ✅ (comment-based job ID, disabled, cron_file)
└── wait_for block                    ✅ (port/path/host, delay/timeout, search_regex)

Phase 2 — Addon Packages
├── configr-firewall
├── configr-mount
├── configr-selinux
├── configr-crypto
├── configr-dconf
├── configr-desktop-entry
├── configr-font
├── configr-vscode
├── configr-ssh
└── configr-docker-compose
```

---

## 7. What Remains

### Next priorities

| Task | Priority | Effort | Dependencies |
|------|----------|--------|-------------|
| **Run container tests** | High | 2 days | Docker host |
| **Update remaining v1-style docs** | Low | 1 day | None (cosmetic) |
| **CI matrix integration** | Medium | 1 day | GitHub Actions access |
| **Stub→full impl for macOS/FreeBSD** | Low | varies | Access to macOS/FreeBSD |
| **Phase 2 addon packages** | Low | varies | Plugin system stable |

### Concrete next steps

1. **Run container tests** — `./testing/scripts/run-all.sh` across all 5 distros
   to verify idempotency and system state changes
2. **CI integration** — add matrix job to `.github/workflows/dart.yml` running
   `testing/scripts/ci-run.sh` per distro with `--privileged` for systemd tests
3. **v1 docs cleanup** — update docs/modules/*.md to remove nested
   `resource { actions { } }` syntax (v1 legacy)
4. **Hermetic v2 parse tests** — add V2TestHelper `processConfig()` tests for
   system blocks to verify property parsing without requiring system access

### Known issues

- **Debian Dockerfile GPG key (fixed)**: Replaced broken `sed` URL rewrite with
   direct `echo "deb [signed-by=..."` approach matching Ubuntu pattern.
- **run-all.sh (fixed)**: Removed dangling `--exit-code-from` flag; now runs
   distro tests sequentially with proper exit code propagation.
- **`dart:io` import in timezone_block.dart** still needed for `Platform`.
- **All 209 tests pass** on Arch Linux as of last run.
- **Ansible subclass pattern** used by 7 system blocks (user, group, hostname,
  timezone, sysctl, locale_gen, alternatives).
