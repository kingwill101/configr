# Rollback System

Configr provides comprehensive rollback for all configuration changes
using a lockfile-based approach.

## How It Works

1. **During apply**: Each successful operation records its block type, source,
   destination, and rollback data to the lockfile.
2. **Lockfile** (`config.lock.json`): Contains SHA-256 checksum of the
   config and a list of applied block records.
3. **During rollback**: Records are processed in reverse order so the newest
   changes are restored first.

## Usage

```bash
# Rollback all changes
configr rollback

# Rollback specific number of operations
configr rollback --count 3
```

## Lockfile Structure

```json
{
  "configChecksum": "abc123...",
  "appliedAt": "2026-06-21T12:00:00Z",
  "blocks": [
    {
      "blockId": "download_0",
      "blockType": "download",
      "source": "https://get.docker.com/",
      "destination": "docker.sh",
      "state": { ... }
    }
  ]
}
```

## Block Identification

Blocks are identified by source+destination property matching, not by
UUID. This allows rollback to work across config file edits.

## Safety

- Lockfile is only written on **successful** apply
- If the config has changed since the lockfile was written, rollback warns
- Each block's rollback is independent — partial rollback is supported
- `--dry-run` shows what would be rolled back without making changes
