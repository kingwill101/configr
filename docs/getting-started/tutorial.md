# Getting Started with Configr v2

This tutorial walks you through setting up and applying your first
configuration with Configr v2.

## Prerequisites

- Dart SDK (3.0+)
- The `configr` binary compiled:
  ```bash
  dart compile exe bin/configr.dart -o build/cli/linux_x64/bundle/bin/configr
  ```

## Step 1: Initialize a Configuration

```bash
configr init
```

This creates a `config` file with example blocks:

```i3
# Configr v2 configuration
config {
  destination = "~/.config"
}

copy {
  source = "dotfiles/bashrc"
  destination = "~/.bashrc"
}

symlink {
  source = "dotfiles/gitconfig"
  destination = "~/.gitconfig"
}
```

## Step 2: Add Files

```bash
# Add a copy block for your bashrc
configr add --file ~/.bashrc --destination "~/.bashrc"

# Add a template block
configr add --file templates/starship.toml.liquid \
  --type template --destination "~/.config/starship.toml"
```

## Step 3: Apply Configuration

```bash
configr apply
```

You'll see live progress output:

```
▶ download_0: Starting download from https://get.docker.com/
✔ download_0: Download completed in 562ms
▶ copy_1: Starting copy of docker.sh to docker.copied.sh
✔ copy_1: Copy completed
```

A lockfile (`config.lock.json`) is written on success.

## Step 4: Check Status

```bash
configr status
```

Shows all configured blocks grouped by type with their status.

## Step 5: Rollback

If something went wrong:

```bash
configr rollback
```

Each block's rollback reverses the operation.

## Example Config

```i3
# Copy dotfiles
copy {
  source = "dotfiles/bashrc"
  destination = "~/.bashrc"
}

copy {
  source = "dotfiles/gitconfig"
  destination = "~/.gitconfig"
}

# Template rendering
template {
  source = "templates/starship.toml.liquid"
  destination = "~/.config/starship.toml"
}

# Package management
package {
  source = "curl git"
  operation = "install"
  package_manager = "apt"
}

# Execute a setup command
execute {
  command = "echo 'Setup complete!'"
}
```

## Next Steps

- See the [CLI Usage Guide](cli-usage.md) for all commands
- Check individual block docs for properties
- Use `--dry-run` to preview changes before applying
