# Plugin System

Configr supports extending the v2 action block pipeline through plugins.
Plugins can register custom block handlers, command handlers, and hook
into the configuration lifecycle.

## Plugin Types

### Dart Plugins

Implement the plugin interface to register custom block handlers:

- Provide a name and description
- Register block handlers with the configuration processor
- Hook into lifecycle events before and after config execution

Register plugins when building your Configr configuration. The plugin loader discovers and initializes them before config execution starts.

### Lua Plugins

Lua plugins use the `lualike` package to define block handlers directly
in Lua scripts, without writing Dart code.

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
| `runCommand(command)` | Run a shell command through Configr's process backend |
| `configrCacheDir()` | Get Configr cache directory |
| `configrBackupDir()` | Get Configr backup directory |
| `emitStatusUpdate(moduleId, level, message)` | Emit a status event |
| `getContext(key)` | Get a value from the context table |

The standard Lua IO APIs and Configr's file helper functions use the runtime
file-system backend for the current apply. In normal local runs they operate
on the local machine. In SSH or multi-host runs they operate on the target host
through the SFTP file system.

Command execution is the exception. Use `runCommand(command)` for Lua plugin
process work so Configr can route the command through the active process
backend, including SSH remotes.

The other Configr helpers are optional convenience APIs. Use them when they
make a plugin clearer or when you need Configr-specific behavior such as
`configrCacheDir()`, `configrBackupDir()`, or `emitStatusUpdate(...)`.

Plugin source files are always read from the controller's file system. This
keeps plugin code local while still allowing the plugin's file and process
effects to target each remote host.

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
entry_point: lib/main.dart
```
