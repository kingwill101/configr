#!/bin/bash
set -e

echo "=== Configr Deployer Setup ==="

# Copy SSH keys from shared volume to deployer SSH dir
mkdir -p /root/.ssh
if [ -f /shared/ssh/id_ed25519 ]; then
  cp /shared/ssh/id_ed25519 /root/.ssh/id_ed25519
  chmod 600 /root/.ssh/id_ed25519
fi
if [ -f /shared/ssh/id_ed25519.pub ]; then
  cp /shared/ssh/id_ed25519.pub /root/.ssh/id_ed25519.pub
fi

# Add VM host keys to known_hosts using hostnames from compose DNS
for vm in vm1 vm2 vm3; do
  echo "Adding $vm to known_hosts"
  mkdir -p /root/.ssh
  ssh-keyscan -H "$vm" >> /root/.ssh/known_hosts 2>/dev/null || true
done

# Pre-build configr for faster test execution
cd /configr
dart pub get >/dev/null 2>&1 || true

echo "=== Setup Complete ==="
