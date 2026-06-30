#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
TMPDIR="${TMPDIR:-/tmp}"

echo "==> Running hooks example from $DIR"
echo ""

# Hooks are in .configr/hooks/ alongside the config file
# configr apply discovers them automatically

echo ">>> configr apply"
dart run "$DIR/../../bin/configr.dart" apply "$DIR/config"
echo ""

echo ">>> configr apply (again — unchanged, will skip)"
dart run "$DIR/../../bin/configr.dart" apply "$DIR/config"
echo ""

echo ">>> configr apply --force (re-runs hooks)"
dart run "$DIR/../../bin/configr.dart" apply --force "$DIR/config"
echo ""

echo "=== Done ==="
