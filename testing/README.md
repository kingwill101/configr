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

## Adding Container Tests

Mark test files with appropriate tags:

```dart
@TestOn('vm')
import 'package:test/test.dart';

void main() {
  test('apt install should work', () {
    // Test that requires apt
  }, tags: 'debian');

  test('systemd service management', () {
    // Requires privileged container
  }, tags: 'needs-systemd');
}
```

## CI Integration

GitHub Actions workflow uses matrix strategy:

```yaml
strategy:
  matrix:
    distro: [ubuntu, debian, fedora, arch, alpine]
```

Each runner executes `testing/scripts/ci-run.sh` which sets `CONFIGR_TEST_ENV` and runs only tests tagged for that environment.