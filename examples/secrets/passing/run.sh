#!/bin/bash
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"

# Create temp .env for dotenv:// provider (needs absolute path)
mkdir -p /tmp/configr_dotenv_example
cp "$DIR/.env" /tmp/configr_dotenv_example/.env

# Run from the passing example directory
cd "$DIR"
CONFIGR_BIN="${CONFIGR_BIN:-configr}"

echo "--- Passing secrets example ---"
echo "Resolving: env://USER, cmd://echo, file:///etc/hostname, cmd://grep .env, dotenv://..."
$CONFIGR_BIN apply "$@"

# Cleanup
rm -rf /tmp/configr_dotenv_example
