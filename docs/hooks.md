# Hooks / Scripts

Configr v2 supports pre-apply and post-apply scripts that run before
and after the action block pipeline executes.

## Configuration

Add `pre_apply_scripts` and/or `post_apply_scripts` blocks to your config:

```i3
pre_apply_scripts {
  "echo 'Starting apply...'"
  "mkdir -p ~/.config/backups"
}

post_apply_scripts {
  "echo 'Apply complete!'"
  "notify-send 'Configr' 'Configuration applied successfully'"
}
```

## Execution

- **Pre-apply scripts**: Run after config parsing, before any blocks execute.
- **Post-apply scripts**: Run after all blocks execute successfully.
- If a pre-apply script fails, a warning is logged but execution continues.
- Scripts run via `/bin/sh -c <script>`.
- Scripts are NOT run in dry-run mode.
