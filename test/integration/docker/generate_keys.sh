#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$SCRIPT_DIR/shared"
KEY_DIR="$SHARED_DIR/ssh"

mkdir -p "$KEY_DIR"
chmod 755 "$KEY_DIR"

if [ ! -f "$KEY_DIR/id_ed25519" ]; then
  echo "Generating SSH test keys..."
  ssh-keygen -t ed25519 -f "$KEY_DIR/id_ed25519" -N "" -q
else
  echo "SSH keys already exist at $KEY_DIR"
fi

echo "Public key:"
cat "$KEY_DIR/id_ed25519.pub"
