# Plugin System

Configr supports Lua plugins for project-specific blocks and hooks. Use plugins
when the built-in blocks are close but you need a small custom operation.

## Lua Plugins

Lua plugins define block handlers directly in Lua scripts.

#### Config File Registration

Add a `plugin` block in your config file **before** any blocks that
depend on it:

```i3
plugin {
  lua = "my_plugin.lua"
}

myplugin {
  source = "hello"
}
```

Paths are resolved relative to the config file's parent directory.

#### Lua Script Structure

A Lua plugin script defines exports as global variables:

```lua
name = "my_plugin"
description = "My custom plugin"
version = "1.0.0"

-- Register a block type
registerBlock("myplugin", {
  execute = function(block)
    logInfo("Executing block: " .. block.id)
    -- block.id, block.source, block.destination, block.properties
  end,

  rollback = function(block)
    logInfo("Rolling back: " .. block.id)
  end,

  -- Optional: register scoped commands for block properties
  commands = {
    myoption = function(value)
      setVariable("myoption", value)
    end
  }
})

-- Lifecycle hooks (optional)
function onConfigLoad(config)
  logInfo("Config loaded")
end

function onConfigApplied(config)
  logInfo("Config applied")
end
```

#### Lua API

| Function | Description |
|----------|-------------|
| `registerBlock(type, callbacks)` | Register a block handler |
| `getEnv(name)` | Get environment variable |
| `getVariable(name)` | Get context variable |
| `setVariable(name, value)` | Set context variable |
| `expandVariables(str)` | Expand `{{ variable }}` in string |
| `logInfo(msg)` | Log info message |
| `logWarning(msg)` | Log warning |
| `logError(msg)` | Log error |
| `logDebug(msg)` | Log debug message |
| `fileExists(path)` | Check if file exists |
| `readFile(path)` | Read file contents |
| `writeFile(path, content)` | Write to file |
| `appendFile(path, content)` | Append to file |
| `configrCacheDir()` | Get Configr cache directory |
| `configrBackupDir()` | Get Configr backup directory |
| `emitStatusUpdate(moduleId, level, message)` | Emit a status event |
| `getContext(key)` | Get a value from the context table |

#### Default Context Info

Every plugin has access to a `context` global table with static
environment and OS information, available at script load time:

```lua
logInfo(context.platform)      -- "linux", "macos", "windows"
logInfo(context.architecture)  -- "x86_64", "aarch64"
logInfo(context.hostname)      -- machine hostname

logInfo(context.os.name)       -- same as platform
logInfo(context.os.version)    -- OS version string

logInfo(context.user.username) -- current user
logInfo(context.user.home)     -- home directory path
logInfo(context.user.shell)    -- login shell path

logInfo(context.env.HOME)      -- common env vars
logInfo(context.env.USER)
logInfo(context.env.SHELL)
logInfo(context.env.TERM)
logInfo(context.env.LANG)
logInfo(context.env.PATH)
logInfo(context.env.EDITOR)
logInfo(context.env.PWD)

logInfo(context.configr.version)  -- Configr version number

-- Use configrCacheDir() / configrBackupDir() at runtime instead
```

Access the same values via `getContext(key)` for a flat key lookup:

```lua
logInfo(getContext("platform"))
logInfo(getContext("hostname"))
```

#### Plugin Directories

Use `--plugin-dir` to add directories for plugin discovery:

```bash
configr apply --plugin-dir ./plugins
```

Or in your config file:

```i3
plugin {
  dir = "./plugins"
}
```

Each plugin directory should contain a `plugin.yaml` or `plugin.json`
manifest:

```yaml
name: my-plugin
version: 1.0.0
description: "A sample plugin"
entry: main.lua
```
