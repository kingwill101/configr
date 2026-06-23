#!/usr/bin/env bash
# Run Configr tests on a specific distro container
# Usage: ./run-distro.sh ubuntu [--test test/v2/some_test.dart] [--tags debian]
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$DIR/docker-compose.yml"

DISTRO="${1:-ubuntu}"
shift 2>/dev/null || true

if ! docker compose -f "$COMPOSE_FILE" config --services 2>/dev/null | grep -q "^${DISTRO}-test$"; then
  echo "Error: Unknown distro '$DISTRO'"
  echo "Available: ubuntu, debian, fedora, arch, alpine"
  exit 1
fi

echo "=== Building $DISTRO test image ==="
docker compose -f "$COMPOSE_FILE" build "${DISTRO}-test"

echo "=== Running $DISTRO tests ==="
if [ $# -eq 0 ]; then
  docker compose -f "$COMPOSE_FILE" run --rm "${DISTRO}-test"
else
  docker compose -f "$COMPOSE_FILE" run --rm "${DISTRO}-test" sh -c "dart pub get && dart test $*"
fi

echo "=== Cleaning up ==="
docker compose -f "$COMPOSE_FILE" down

echo "=== $DISTRO tests completed ==="