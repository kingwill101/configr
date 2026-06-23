#!/usr/bin/env bash
# Run Configr tests across all distro containers in parallel
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$DIR/docker-compose.yml"

echo "=== Building test images ==="
docker compose -f "$COMPOSE_FILE" build

echo "=== Running all container tests ==="
docker compose -f "$COMPOSE_FILE" --profile all up --abort-on-container-exit --exit-code-from

echo "=== Cleaning up ==="
docker compose -f "$COMPOSE_FILE" --profile all down

echo "=== All tests completed ==="