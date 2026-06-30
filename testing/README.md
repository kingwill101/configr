# Container-Based Testing

This directory contains infrastructure for testing Configr blocks in real Linux environments. Many blocks (package managers, systemd, user/group management, etc.) require actual system tools and cannot be tested with in-memory filesystem mocks.

## Directory Structure

```
testing/
├── containers/
│   ├── ubuntu/       # Ubuntu 24.04 with systemd, apt, snap, flatpak
│   ├── debian/       # Debian Bookworm with systemd, apt
│   ├── fedora/       # Fedora 40 with systemd, dnf
│   ├── arch/         # Arch Linux with systemd, pacman
│   └── alpine/       # Alpine 3.20 for musl compatibility
├── scripts/
│   ├── run-distro.sh    # Run tests on specific distro
│   ├── run-all.sh       # Run tests on all distros in parallel
│   └── ci-run.sh        # CI-optimized runner
└── docker-compose.yml   # Container matrix definition
```

## Quick Start

```bash
# Run tests on a specific distro
./testing/scripts/run-distro.sh ubuntu

# Run all distro tests in parallel
./testing/scripts/run-all.sh

# Or use docker-compose directly
docker compose -f testing/docker-compose.yml build
docker compose -f testing/docker-compose.yml run --rm ubuntu-test
```

## Test Tagging

Tests are tagged by environment in `dart_test.yaml`:

- `debian` — Tests that run on Ubuntu and Debian
- `fedora` — Tests that run on Fedora
- `arch` — Tests that run on Arch Linux
- `alpine` — Tests that run on Alpine Linux
- `needs-systemd` — Tests requiring privileged container with systemd
- `needs-docker` — Tests requiring Docker socket access

Run tagged tests:
```bash
dart test --tags debian
dart test --tags fedora
```

## Test Patterns

### 1. Idempotency

Every test verifies that running the same config twice produces no changes:

```dart
test('creates a user and is idempotent', () async {
  final first = await configrApply(config);
  expect(first.isSuccess, isTrue);

  final second = await configrApply(config);
  expect(second.isChanged, isFalse);
}, tags: needsRootTag);
```

### 2. Check-Mode / Dry-Run

Tests verify `--dry-run` shows correct output without modifying state:

```dart
final dry = await configrApply(config, dryRun: true);
expect(dry.isDryRun, isTrue);
```

### 3. Distro-Specific Tests

Tag tests with the distro they run on and set up/tear down accordingly:

```dart
test('apt install works', () {
  // Runs on Ubuntu/Debian only
}, tags: 'debian');

test('systemd service', () {
  // Requires privileged container
}, tags: 'needs-systemd');
```

### 4. Clean State

Each test cleans up state in `teardown`/`finally` blocks. Tests should
be independently runnable.

### 5. Shared Utilities

The `helpers/configr_test_utils.dart` file provides:

- `configrApply(config)` — runs `configr apply --v2`, returns `ConfigrResult`
- `assertIdempotent(config)` — runs twice, asserts no change on second
- `assertCheckMode(config)` — runs `--dry-run`, asserts dry-run output
- `shell(command)` — runs shell command, returns trimmed stdout
- `shellLines(command)` — runs shell command, returns lines as list

### 6. Test Tags

| Tag | Description |
|-----|-------------|
| `debian` | Debian/Ubuntu environment required |
| `fedora` | Fedora/RHEL environment required |
| `arch` | Arch Linux environment required |
| `alpine` | Alpine Linux environment required |
| `needs-systemd` | Requires privileged container with systemd |
| `needs-root` | Requires root privileges (useradd, groupdel, etc.) |
| `destructive` | Modifies system state, run in isolation |
| `container` | Requires Docker-in-Docker (testcontainers) |

## CI Integration

GitHub Actions workflow uses matrix strategy:

```yaml
strategy:
  matrix:
    distro: [ubuntu, debian, fedora, arch, alpine]
```

Each runner executes `testing/scripts/ci-run.sh` which sets `CONFIGR_TEST_ENV` and runs only tests tagged for that environment.