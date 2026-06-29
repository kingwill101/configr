# Plugin Block

The `plugin` block loads Lua plugins or adds a plugin directory while the
configuration is being parsed.

```i3
plugin {
  lua = "./plugins/my_plugin.lua"
}

plugin {
  dir = "./plugins"
}
```

## Properties

| Property | Description |
|----------|-------------|
| `lua` | Path to a Lua plugin file |
| `dir` | Directory added to plugin discovery |

Relative paths are resolved against the directory containing the config file.
Declare plugin blocks before any custom blocks that depend on the plugin.

See the [plugin system guide](../guides/plugin-system.md) for plugin authoring
details.

