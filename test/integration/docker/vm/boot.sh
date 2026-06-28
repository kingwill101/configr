#!/bin/bash
set -e

# Wait for SSH keys to be injected by shared volume
while [ ! -f /shared/ssh/id_rsa.pub ]; do
  echo "Waiting for SSH keys..."
  sleep 1
done

mkdir -p /root/.ssh
chmod 700 /root/.ssh
cp /shared/ssh/id_rsa.pub /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# Also copy to tester user for convenience
mkdir -p /home/tester/.ssh
cp /shared/ssh/id_rsa.pub /home/tester/.ssh/authorized_keys
chown -R tester:tester /home/tester/.ssh

# Start SSH
service ssh start || /usr/sbin/sshd

echo "Configr test VM ready"
exec sleep infinity
