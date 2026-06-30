#!/usr/bin/env bash
# Run Configr tests across all distro containers sequentially
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISTROS=("$@")

if [ ${#DISTROS[@]} -eq 0 ]; then
  DISTROS=(ubuntu debian fedora arch alpine)
fi

FAILED=()
for distro in "${DISTROS[@]}"; do
  echo ""
  echo "========== Running $distro tests =========="
  if "$DIR/run-distro.sh" "$distro"; then
    echo "========== $distro PASSED =========="
  else
    echo "========== $distro FAILED =========="
    FAILED+=("$distro")
  fi
done

echo ""
if [ ${#FAILED[@]} -eq 0 ]; then
  echo "=== All distro tests passed ==="
else
  echo "=== FAILED distros: ${FAILED[*]} ==="
  exit 1
fi
