# Configr Roadmap: Ansible-Inspired Module Expansion & Container Testing

## 1. Current State

31 action blocks implemented across 6 categories. See [docs/index.md](docs/index.md) for the full list.

### Notable gaps vs Ansible builtin modules

| Category | Configr Status | Ansible Comparison |
|----------|---------------|-------------------|
| File operations (copy, move, delete, symlink, touch) | ✅ Full coverage | On par with `ansible.builtin.{copy,file}` |
| File content editing (create, append, prepend, replace) | 🟡 Partial | Has `file { create/edit }` but missing regex `lineinfile`, `blockinfile`, `replace` |
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
| **User/group management** | ❌ Missing | `ansible.builtin.{user,group}` |
| **Regex file editing (lineinfile/blockinfile)** | ❌ Missing | `ansible.builtin.{lineinfile,blockinfile}` |
| **System settings (hostname, timezone, sysctl, locale)** | ❌ Missing | `ansible.posix.{hostname,timezone,sysctl}`, `locale_gen` |
| **Cron jobs** | ❌ Missing | `ansible.builtin.cron` |
| **Alternatives** | ❌ Missing | `community.general.alternatives` |
| **Assert/wait_for** | ❌ Missing | `ansible.builtin.{assert,wait_for}` |
| **Firewall (ufw, firewalld)** | ❌ Missing | Plugin territory |
| **Mount** | ❌ Missing | Plugin territory |
| **SELinux** | ❌ Missing | Plugin territory |
| **Crypto (certificates, keys)** | ❌ Missing | Plugin territory |
| **Desktop/GUI (dconf, .desktop, fonts)** | ❌ Missing | Plugin territory |

---

## 2. Phase 1: Core Blocks (Out of the Box)

These directly map to common dotfiles/system-config tasks and should ship as built-in blocks.

### 2.1 `user` block

Ansible equivalent: `ansible.builtin.user`

```
user {
  name = "john"
  state = "present"          # present | absent
  uid = 1001
  group = "users"
  groups = "wheel,docker"
  shell = "/bin/zsh"
  home = "/home/john"
  create_home = true
  password_hash = "$6$..."
  ssh_authorized_keys = ["ssh-ed25519 AAA..."]
}
```

Operations: `create`, `modify`, `remove`, `lock`, `unlock`

### 2.2 `group` block

Ansible equivalent: `ansible.builtin.group`

```
group {
  name = "mygroup"
  state = "present"          # present | absent
  gid = 1002
  system = false
}
```

Operations: `create`, `remove`

### 2.3 `lineinfile` block

Ansible equivalent: `ansible.builtin.lineinfile`

```
lineinfile {
  path = "~/.bashrc"
  regexp = "^export EDITOR="
  line = "export EDITOR=vim"
  state = "present"          # present | absent
  insert_after = "^# Aliases"
  insert_before = "^# End"
  backup = true
  create = true
}
```

Operations: `ensure_line`, `remove_line`, `replace_line`

### 2.4 `blockinfile` block

Ansible equivalent: `ansible.builtin.blockinfile`

```
blockinfile {
  path = "~/.ssh/config"
  marker = "# {mark} ANSIBLE MANAGED BLOCK"
  block = """
Host github.com
  HostName github.com
  IdentityFile ~/.ssh/id_ed25519
"""
  state = "present"          # present | absent
  create = true
  backup = true
}
```

Operations: `ensure_block`, `remove_block`

### 2.5 `replace` block

Ansible equivalent: `ansible.builtin.replace`

```
replace {
  path = "/etc/nginx/nginx.conf"
  regexp = "worker_connections\\s+\\d+"
  replace = "worker_connections 2048"
  backup = true
  after = "events\\s*\\{"
  before = "}"
}
```

### 2.6 `hostname` block

```
hostname {
  name = "my-machine"
  use_hostnamectl = true     # Use hostnamectl (systemd) vs /etc/hostname
}
```

### 2.7 `timezone` block

```
timezone {
  zone = "America/New_York"
}
```

### 2.8 `sysctl` block

```
sysctl {
  name = "net.ipv4.ip_forward"
  value = "1"
  state = "present"          # present | absent
  reload = true
  sysctl_file = "/etc/sysctl.d/99-custom.conf"
}
```

### 2.9 `cron` block

```
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

### 2.10 `locale_gen` block

```
locale_gen {
  locale = "en_US.UTF-8"
  state = "present"          # present | absent
}
```

### 2.11 `alternatives` block

```
alternatives {
  name = "editor"            # Master link name (e.g. editor, java, python)
  path = "/usr/bin/vim.basic"
  link = "/usr/bin/editor"
  priority = 50
  state = "auto"             # auto | manual
}
```

### 2.12 `assert` block

```
assert {
  condition = "$os_family == 'debian'"
  fail_msg = "This block only works on Debian-based systems"
  success_msg = "Confirmed: Debian-based system"
}
```

### 2.13 `wait_for` block

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

## 4. Missing Docs

5 blocks are implemented in source but lack dedicated docs:

| Block | Source | Missing Doc |
|-------|--------|-------------|
| echo | `lib/src/blocks/echo_block.dart` | `docs/echo.md` |
| file | `lib/src/blocks/file_block.dart` | `docs/file.md` |
| git | `lib/src/blocks/git_block.dart` | `docs/git.md` |
| network | `lib/src/blocks/network_block.dart` | `docs/network.md` |
| systemd | `lib/src/blocks/systemd_block.dart` | `docs/systemd.md` |

---

## 5. Container-Based Testing Solution

### 5.1 Problem

Many blocks (package managers, systemd, user/group, hostname, timezone, etc.)
cannot be tested with the existing in-memory filesystem approach. They need
real environments with specific distros and installed tools.

### 5.2 Architecture

```
testing/
├── containers/
│   ├── ubuntu/
│   │   └── Dockerfile          # Ubuntu 24.04 with Dart SDK + configr deps
│   ├── debian/
│   │   └── Dockerfile          # Debian bookworm with Dart SDK + configr deps
│   ├── fedora/
│   │   └── Dockerfile          # Fedora 40 with Dart SDK + configr deps
│   ├── arch/
│   │   └── Dockerfile          # Arch Linux with Dart SDK + configr deps
│   ├── alpine/
│   │   └── Dockerfile          # Alpine for testing musl compatibility
│   ├── macos/ (future)
│   │   └── ...                 # macOS containers? (limited)
│   └── base/
│       └── Dockerfile          # Common base image layer
├── images/
│   └── ...                     # Pre-built docker-compose variations
├── docker-compose.yml          # Matrix: ubuntu + debian + fedora + arch
├── scripts/
│   ├── run-all.sh              # Build images + run tests across all distros
│   ├── run-distro.sh           # Run tests on a specific distro
│   └── ci-run.sh               # CI-optimized runner (parallel matrix)
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

Use Dart's `@TestOn` and custom tags to route tests to the right container:

```yaml
# dart_test.yaml
tags:
  debian:
    description: "Tests that require Debian/Ubuntu environment"
  fedora:
    description: "Tests that require Fedora/RHEL environment"
  arch:
    description: "Tests that require Arch Linux environment"
  alpine:
    description: "Tests that require Alpine Linux environment"
  needs-docker:
    description: "Tests that require Docker-in-Docker or Docker socket"
  needs-systemd:
    description: "Tests that require systemd (needs privileged container)"
```

Test example:

```dart
@TestOn('vm')
import 'package:test/test.dart';

void main() {
  test('apt install should work', () {
    // Only runs when tag 'debian' is active
  }, tags: 'debian');
}
```

### 5.5 Test Runner Script

```bash
# Run all container tests
testing/scripts/run-all.sh

# Run specific distro
testing/scripts/run-distro.sh ubuntu
testing/scripts/run-distro.sh fedora

# Run specific test file in a container
docker compose run --rm ubuntu-test dart test test/v2/package_test.dart --tags debian
```

### 5.6 CI Integration

Extend `.github/workflows/dart.yml`:

```yaml
strategy:
  matrix:
    container:
      - ubuntu:24.04
      - debian:bookworm
      - fedora:40
      - archlinux:latest

container:
  image: configr-test-${{ matrix.container }}
  options: --privileged  # Needed for systemd tests

steps:
  - uses: actions/checkout@v4
  - run: dart test --tags $(echo ${{ matrix.container }} | cut -d: -f1)
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
| execute | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| download | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| network | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| echo | ✅ | — | — | — | — | — |
| git | — | ✅ | ✅ | ✅ | ✅ | ✅ |
| systemd | — | ✅ | ✅ | ✅ | ✅ | ❌ |
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
| **user** (new) | — | ✅ | ✅ | ✅ | ✅ | ✅ |
| **group** (new) | — | ✅ | ✅ | ✅ | ✅ | ✅ |
| **lineinfile** (new) | ✅ | — | — | — | — | — |
| **blockinfile** (new) | ✅ | — | — | — | — | — |
| **replace** (new) | ✅ | — | — | — | — | — |
| **hostname** (new) | — | ✅ | ✅ | ✅ | ✅ | ✅ |
| **timezone** (new) | — | ✅ | ✅ | ✅ | ✅ | ✅ |
| **sysctl** (new) | — | ✅ | ✅ | ✅ | ✅ | ✅ |
| **cron** (new) | — | ✅ | ✅ | ✅ | ✅ | — |
| **locale_gen** (new) | — | ✅ | ✅ | — | — | — |
| **alternatives** (new) | — | ✅ | ✅ | ✅ | ✅ | — |
| **assert** (new) | ✅ | — | — | — | — | — |
| **wait_for** (new) | — | ✅ | ✅ | ✅ | ✅ | ✅ |

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
Phase 1a — Foundation (next sprint)
├── Missing docs: echo.md, file.md, git.md, network.md, systemd.md
├── container testing infrastructure (Dockerfiles, scripts)
└── Tag existing tests with environment markers

Phase 1b — Core Blocks (sprint after)
├── lineinfile block   (high value, lots of file-based tests via MemFS)
├── blockinfile block  (high value, MemFS-testable)
├── replace block      (high value, MemFS-testable)
├── user block         (needs containers)
├── group block        (needs containers)
├── assert block       (simple, MemFS-testable)
└── wait_for block     (needs containers)

Phase 1c — System Blocks
├── hostname block     (needs containers)
├── timezone block     (needs containers)
├── sysctl block       (needs containers)
├── cron block         (needs containers)
├── locale_gen block   (needs containers)
└── alternatives block (needs containers)

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
