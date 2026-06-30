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

## Lua Hooks and Remote Runs

Lua hook files are loaded from the controller's `.configr` path or configured
hook directories. In SSH and multi-host applies, the hook source stays local
but Lua IO APIs and Configr's file helpers target the active remote runtime:

```lua
writeFile("/tmp/configr_hook_test", "created by hook\n")
runCommand("printf remote >> /tmp/configr_hook_test")
```

Configr's Lua helpers are available for host side effects:

- `fileExists`, `readFile`, `writeFile`, and `appendFile` use the active file
  system backend.
- `runCommand(command)` uses the active process backend and should be used for
  command execution from hooks.

For remote targets, file IO goes through SFTP and `runCommand(command)` goes
through SSH. The file helpers are convenience APIs; standard Lua IO should
continue to work through the same file-system integration.
