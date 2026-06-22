#!/usr/bin/env bash
set -euo pipefail

echo "=== dotfiles-bootstrap: configr integration test ==="

# Run configr apply against the example config
configr apply -n 2>&1 || true

# Check that journal.csv contains expected entries
echo ""
echo "=== Checking journal.csv ==="
JOURNAL="$HOME/.cache/configr/journal.csv"
if [[ ! -f "$JOURNAL" ]]; then
  echo "FAIL: journal.csv not found at $JOURNAL"
  echo "Searching for journal.csv..."
  find / -name "journal.csv" 2>/dev/null
  exit 1
fi

echo "journal.csv contents:"
cat "$JOURNAL"

# Verify expected journal entries (bootstrap entries come from config,
# install from packages.conf, deploy from dotfiles.conf)
grep -q "install,cli-tools,started" "$JOURNAL" || {
  echo "FAIL: missing install started entry"
  exit 1
}
grep -q "install,cli-tools,done" "$JOURNAL" || {
  echo "FAIL: missing install done entry"
  exit 1
}
grep -q "deploy,dotfiles,started" "$JOURNAL" || {
  echo "FAIL: missing deploy started entry"
  exit 1
}
grep -q "deploy,dotfiles,done" "$JOURNAL" || {
  echo "FAIL: missing deploy done entry"
  exit 1
}

# Verify copied files exist
echo ""
echo "=== Checking deployed files ==="
BASE="/examples/dotfiles-bootstrap"
for f in "output/gitconfig" "output/gitignore" "output/init.lua" \
         "output/kitty.conf" "output/zshrc"; do
  if [[ -f "$BASE/$f" ]]; then
    echo "  ✔ $f"
  else
    echo "  ✘ $f missing"
  fi
done

echo ""
echo "=== All checks passed! ==="
