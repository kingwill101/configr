import 'dart:async';

import 'package:configr/src/plugins/configr_plugin.dart';
import 'package:configr/src/plugins/lua_plugin.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:file/local.dart';
import 'package:i3config/i3config_v2.dart' as i3;

/// Processes `plugin { ... }` blocks in config files.
///
/// Supports two configurations:
/// - `lua = "path/to/plugin.lua"` — loads a Lua plugin script
/// - `dir = "./plugins"` — adds a plugin directory for discovery
///
/// Paths are resolved relative to the config file's parent directory.
///
/// ## Ordering
/// The `plugin` block must appear **before** any blocks that depend on the
/// plugin's registered handlers. For example:
///
/// ```i3
/// plugin {
///   lua = "my_plugin.lua"
/// }
/// myplugin { ... }   # ← works because my_plugin.lua registered it
/// ```
class PluginBlockHandler extends i3.BaseBlockHandler {
  @override
  String get blockType => 'plugin';

  final i3.ConfigProcessor processor;
  final ConfigrPluginLoader pluginLoader;
  final String configDir;
  final EventBus? eventBus;

  PluginBlockHandler({
    required this.processor,
    required this.pluginLoader,
    required this.configDir,
    this.eventBus,
  });

  @override
  FutureOr<void> handle(i3.Block block, i3.Context context) {
    // Variables (lua, dir) are set during children processing,
    // so all work is done in afterChildrenProcessed.
  }

  @override
  Future<void> afterChildrenProcessed(
    i3.Block block,
    i3.Context context,
  ) async {
    final luaPath = context.getVariable('lua') as String?;
    if (luaPath != null && luaPath.isNotEmpty) {
      final resolvedPath = _resolvePath(luaPath, configDir);
      final fs = const LocalFileSystem();
      final file = fs.file(resolvedPath);
      if (await file.exists()) {
        final plugin = LuaPlugin(scriptPath: resolvedPath);
        await plugin.initialize();
        plugin.registerBlocks(processor, eventBus: eventBus);
        pluginLoader.registerPlugin(plugin);
        logger.info('Loaded plugin from config: $resolvedPath');
      } else {
        logger.warning('Plugin file not found: $resolvedPath');
      }
    }

    final dir = context.getVariable('dir') as String?;
    if (dir != null && dir.isNotEmpty) {
      final resolvedDir = _resolvePath(dir, configDir);
      final fs = const LocalFileSystem();
      final directory = fs.directory(resolvedDir);
      if (await directory.exists()) {
        pluginLoader.pluginDirectories.add(resolvedDir);
        logger.info('Added plugin directory from config: $resolvedDir');
      } else {
        logger.warning('Plugin directory not found: $resolvedDir');
      }
    }
  }

  static String _resolvePath(String path, String configDir) {
    if (path.startsWith('/')) return path;
    return '$configDir/$path';
  }
}
