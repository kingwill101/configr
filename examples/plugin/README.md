# Plugin Example: Lua notify plugin

This example demonstrates using a Lua plugin (`plugin.lua`) to add custom
action blocks to a configr configuration.

## How it works

The Lua script registers a `notify` block type via `registerBlock()`. Each
`notify { }` block in the config triggers the plugin's `execute` callback,
which:

- Reads the `message` variable set inside the block
- Logs the message via `logInfo()`
- Emits a status update event
- Sets a context variable (`notify_message`) for downstream use
- Writes to `/tmp/notify.log`

## Running

### Via CLI flag

```bash
configr apply --plugin plugin.lua
```

The `--plugin` flag loads the Lua script before processing the config file.

### Via config block (no CLI flag needed)

Add a `plugin { lua = "..." }` block at the top of your config. The example
config already includes one:

```i3
plugin {
  lua = "plugin.lua"
}
```

Paths are relative to the config file's directory. Both approaches work;
use whichever is more convenient for your workflow.

## Plugin capabilities

| Function | Purpose |
|----------|---------|
| `getVariable(name)` | Read a config variable |
| `setVariable(name, value)` | Set a config variable (persists after block) |
| `expandVariables(text)` | Expand `$variable` references |
| `logInfo(msg)` / `logWarning(msg)` / `logError(msg)` | Emit log messages |
| `emitStatusUpdate(id, level, msg)` | Emit a status event |
| `writeFile(path, content)` / `readFile(path)` | File I/O |
| `fileExists(path)` | Check file existence |
| `getEnv(name)` | Read environment variables |

Register a block with:

```lua
registerBlock("my_block", {
  execute = function(block) ... end,
  rollback = function(block) ... end,
  commands = {
    my_cmd = function(arg1, arg2) ... end
  }
})
```

Commands inside a block (e.g., `greet "Alice"`) are dispatched to
the `commands` table handlers.
