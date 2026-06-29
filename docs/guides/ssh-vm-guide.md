# SSH VM Integration Guide

This guide walks through launching Docker-based VM containers and applying
configr configurations to them over SSH — exactly what the integration tests
do, but manually so you can understand every step.

## Architecture

```
Host machine                     Docker network
┌─────────────────┐             ┌──────────────────────┐
│  configr CLI     │   SSH :2221 │  vm1 (Ubuntu 22.04)  │
│  SSH/SFTP        │────────────▶│  openssh-server       │
│                  │             │  target filesystem    │
│  inventory {     │             └──────────────────────┘
│    host "vm1" {  │
│      hostname =  │             ┌──────────────────────┐
│      "localhost" │   SSH :2222 │  vm2 (Ubuntu 22.04)  │
│      port = 2221 │────────────▶│  openssh-server       │
│      user = root │             │  configr binary       │
│    }             │             └──────────────────────┘
│  }               │
└─────────────────┘                    ...
```

Each VM is a Docker container running `openssh-server`. The host machine acts
as the controller: it keeps the config locally and sends file and process
operations to the VMs over SSH/SFTP.

## Prerequisites

- **Docker** with `docker compose` plugin
- **configr** binary on the host machine
- SSH key pair (Ed25519 recommended)

## Step 1: Generate SSH Keys

The shared service auto-generates keys, but for manual testing you can
generate them locally:

```bash
# From the project root
ssh-keygen -t ed25519 -f test/integration/docker/shared/ssh/id_ed25519 -N ""
cp test/integration/docker/shared/ssh/id_ed25519.pub \
   test/integration/docker/shared/ssh/id_ed25519.pub
```

Or use the helper script:

```bash
bash test/integration/docker/generate_keys.sh
```

## Step 2: Build and Start VMs

```bash
# Build and start all VMs + shared key service
docker compose -f test/integration/docker/docker-compose.yml up -d --build

# Wait for VMs to be healthy (port 22 open)
docker compose -f test/integration/docker/docker-compose.yml ps
```

Expected output shows 3 VMs + shared service healthy:

```
NAME                       IMAGES                          STATUS
configr-test-shared-1      configr-test-shared             healthy
configr-test-vm1-1         configr-test-vm1                healthy  (port 2221)
configr-test-vm2-1         configr-test-vm2                healthy  (port 2222)
configr-test-vm3-1         configr-test-vm3                healthy  (port 2223)
```

> Each VM has the configr binary at `/usr/local/bin/configr` and SSH access
> for `root` (and `tester`) using the generated Ed25519 key.

## Step 3: Verify SSH Access

Test that you can reach the VMs from the host:

```bash
ssh -i test/integration/docker/shared/ssh/id_ed25519 \
    -p 2221 \
    -o StrictHostKeyChecking=no \
    root@localhost hostname
# → vm1

ssh -i test/integration/docker/shared/ssh/id_ed25519 \
    -p 2222 \
    -o StrictHostKeyChecking=no \
    root@localhost hostname
# → vm2
```

## Step 4: Write a Config with Inventory

Create a config file that declares your inventory and the operations to run:

```i3
# deploy.i3

inventory {
  host "vm1" {
    address = "localhost"
    port = 2221
    user = "root"
    privateKey = "/absolute/path/to/test/integration/docker/shared/ssh/id_ed25519"
    roles = ["web"]
  }

  host "vm2" {
    address = "localhost"
    port = 2222
    user = "root"
    privateKey = "/absolute/path/to/test/integration/docker/shared/ssh/id_ed25519"
    roles = ["db"]
  }

  host "vm3" {
    address = "localhost"
    port = 2223
    user = "root"
    privateKey = "/absolute/path/to/test/integration/docker/shared/ssh/id_ed25519"
    roles = ["worker"]
  }
}

file {
  file_path = "/tmp/configr_deploy_test"
  content = "Deployed by configr!"
}

echo {
  message = "Hello from configr on vm1"
}
```

> **Important**: The `privateKey` value must be an absolute path to the key
> file. The inventory block reads the file and passes its PEM content to the
> SSH layer.

## Step 5: Apply Config to a Specific VM

Use `--target` to select which host(s) to target:

```bash
# Dry-run first
configr apply --config deploy.i3 --no-interaction \
    --target vm1 --dry-run

# Real apply
configr apply --config deploy.i3 --no-interaction \
    --target vm1
```

### Targeting by role

```bash
# Apply to all hosts with role "web"
configr apply --config deploy.i3 --no-interaction \
    --target-role web
```

### Targeting by group

```bash
configr apply --config deploy.i3 --no-interaction \
    --target-group production
```

### Targeting multiple hosts

```bash
configr apply --config deploy.i3 --no-interaction \
    --target vm1 --target vm2
```

## Step 6: Execution Strategies

Control **how** hosts are processed:

```bash
# One at a time (default)
configr apply --config deploy.i3 --no-interaction \
    --target vm1 --target vm2 --strategy linear

# All at once
configr apply --config deploy.i3 --no-interaction \
    --target vm1 --target vm2 --strategy parallel

# Boot-group order (by host priority)
configr apply --config deploy.i3 --no-interaction \
    --target vm1 --target vm2 --target vm3 --strategy serial
```

## Step 7: Verify Results

Check the file was created on the target VM:

```bash
docker compose -f test/integration/docker/docker-compose.yml \
    exec -T vm1 cat /tmp/configr_deploy_test
# → Deployed by configr!
```

Check the per-host lockfile:

```bash
ls -la deploy.i3.*.lock.json
# → deploy.i3.vm1.lock.json
```

## Step 8: Rollback

Rollback the changes on a specific host:

```bash
# Via inventory (auto-resolves connection config from inventory block)
configr rollback --config deploy.i3 --no-interaction \
    --host vm1

# Via explicit SSH flags
configr rollback --config deploy.i3 --no-interaction \
    --host localhost --ssh-port 2221 --ssh-key /path/to/id_ed25519
```

Verify the file was removed:

```bash
docker compose -f test/integration/docker/docker-compose.yml \
    exec -T vm1 test -f /tmp/configr_deploy_test && echo EXISTS || echo MISSING
# → MISSING
```

## Using the Inline Connection Block (Single Host)

For a simpler single-target setup, use the `connection { }` block instead of
inventory:

```i3
connection {
    host = "localhost"
    port = 2221
    username = "root"
    private_key = "/absolute/path/to/id_ed25519"
}

file {
    file_path = "/tmp/single_test"
    content = "Single host deploy"
}

# All blocks after connection { } run on the remote host
```

Then apply without `--target`:

```bash
configr apply --config single.i3 --no-interaction
```

## Cleanup

Stop and remove the VMs:

```bash
docker compose -f test/integration/docker/docker-compose.yml down --volumes
```

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `SSH host is required` | No `--host` or `--target` flag | Add `--target <name>` or `--host <addr>` |
| `Source file not found` | Path to private key is relative | Use absolute path in `privateKey` |
| `Connection refused` | VM not started / port mismatch | Check `docker compose ps`, verify port |
| `Host key verification failed` | Unknown host key | Add `-o StrictHostKeyChecking=no` or pre-scan keys |
| `Permission denied (publickey)` | Wrong key or user | Verify `id_ed25519.pub` is in VM's `authorized_keys` |
