import 'dart:convert';

import 'package:configr/src/plugins/lua_plugin.dart';
import 'package:configr/src/plugins/plugin_context.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:file/local.dart';
import 'package:i3config/i3config_v2.dart' as i3;

/// A configr plugin that can extend the v2 ActionBlock pipeline.
///
/// Plugins implement this interface to:
/// - Register custom block handlers into the i3config v2 processor pipeline.
/// - Register custom command handlers for block-scoped properties.
/// - Hook into the config lifecycle (load, pre-apply, post-apply).
///
/// The [registerBlocks] method is called during
/// [ConfigrPluginLoader.registerAllPlugins] — the same phase where built-in
/// action blocks are registered.  A plugin can register any combination of:
///
/// * [i3.BlockHandler] via `processor.registerBlockHandler(...)` —
///   for top-level config blocks (e.g. `myblock { ... }`)
/// * Block-scoped [i3.BlockHandler] via
///   `processor.registerScopedBlockHandler(scope, handler)` —
///   for nested blocks under a parent (e.g. `myblock { subblock { } }`)
/// * Block-scoped [i3.CommandHandler] via
///   `processor.registerScopedCommandHandler(scope, handler)` —
///   for property-style commands that use `=` syntax
///
/// ## Minimal example
///
/// ```dart
/// class GreetPlugin extends ConfigrPlugin {
///   @override
///   String get name => 'greet';
///
///   @override
///   String get description => 'Adds a "greet" action block';
///
///   @override
///   void registerBlocks(i3.ConfigProcessor processor, {EventBus? eventBus}) {
///     processor.registerBlockHandler(GreetBlock(eventBus: eventBus));
///   }
/// }
/// ```
abstract class ConfigrPlugin {
  /// Short plugin name (e.g. `"docker"`, `"kube"`).
  String get name;

  /// Human-readable description shown in status / help output.
  String get description;

  /// Plugin version for dependency resolution (semver string).
  String get version => '0.1.0';

  /// Initialize the plugin before registration.
  Future<void> initialize() async {}

  /// Called once during i3 config processor setup.
  ///
  /// Register custom block handlers, scoped command handlers, etc. onto
  /// [processor].  The [eventBus] is the shared runtime event bus; pass it
  /// to block constructors so they can emit progress/completion events.
  void registerBlocks(i3.ConfigProcessor processor, {EventBus? eventBus});

  /// Called after the config file has been parsed and all blocks are
  /// registered, but before execution begins.
  ///
  /// Override to perform plugin-specific pre-processing or validation.
  Future<void> onConfigLoad(i3.Config config) async {}

  /// Called after all blocks have been processed (applied or dry-run).
  ///
  /// Override to perform cleanup, emit summary events, etc.
  Future<void> onConfigApplied(i3.Config config) async {}
}

/// Metadata discovered from a plugin manifest (`plugin.yaml` / `plugin.json`).
class PluginManifest {
  final String name;
  final String version;
  final String description;
  final String entryPoint;
  final String? directory;

  const PluginManifest({
    required this.name,
    required this.version,
    required this.description,
    required this.entryPoint,
    this.directory,
  });

  factory PluginManifest.fromYaml(Map<String, dynamic> map, {String? dir}) {
    return PluginManifest(
      name: map['name'] as String? ?? 'unknown',
      version: map['version'] as String? ?? '0.0.0',
      description: map['description'] as String? ?? '',
      entryPoint: map['entry_point'] as String? ?? 'plugin.dart',
      directory: dir,
    );
  }

  factory PluginManifest.fromJson(Map<String, dynamic> map, {String? dir}) {
    return PluginManifest(
      name: map['name'] as String? ?? 'unknown',
      version: map['version'] as String? ?? '0.0.0',
      description: map['description'] as String? ?? '',
      entryPoint: map['entry_point'] as String? ?? 'plugin.dart',
      directory: dir,
    );
  }
}

/// Discovers and loads plugins from configured directories.
///
/// Each plugin directory should contain a `plugin.yaml` (or `plugin.json`)
/// manifest file and the plugin's Dart source files.
///
/// ## Current limitations
///
/// * This loader discovers manifest metadata but does **not** dynamically
///   compile or isolate-load plugin Dart code.  Plugins must be registered
///   programmatically via [ConfigrConfig.plugins] or by passing
///   [ConfigrPlugin] instances to the config at startup.
/// * File-system scanning (G.3) is implemented — plugin.yaml/plugin.json
///   manifests are discovered and read, but the actual plugin Dart code is
///   not loaded dynamically (G.5 remains a stretch goal).
class ConfigrPluginLoader {
  final List<String> pluginDirectories;
  final List<String> pluginFiles;
  final List<ConfigrPlugin> _programmaticPlugins = [];

  ConfigrPluginLoader({
    this.pluginDirectories = const [],
    this.pluginFiles = const [],
  });

  /// Register a plugin instance programmatically (preferred approach).
  void registerPlugin(ConfigrPlugin plugin) {
    _programmaticPlugins.add(plugin);
  }

  /// Register multiple plugin instances at once.
  void registerPlugins(Iterable<ConfigrPlugin> plugins) {
    _programmaticPlugins.addAll(plugins);
  }

  /// Returns all available plugins: programmatically-registered ones plus
  /// any discovered from file-system directories.
  ///
  /// Scans each directory in [pluginDirectories] for `plugin.yaml` or
  /// `plugin.json` manifest files.  Manifest metadata is captured in
  /// [PluginManifest] objects, but the actual plugin Dart code is **not**
  /// loaded dynamically — only programmatic registration works at runtime.
  Future<List<ConfigrPlugin>> discoverPlugins() async {
    final plugins = <ConfigrPlugin>[..._programmaticPlugins];
    final fs = const LocalFileSystem();

    // Scan pluginDirectories for plugin.yaml / plugin.json manifests.
    for (final dir in pluginDirectories) {
      final directory = fs.directory(dir);
      if (!await directory.exists()) {
        logger.warning('Plugin directory does not exist: $dir');
        continue;
      }

      // Look for plugin.yaml or plugin.json
      final yamlFile = directory.childFile('plugin.yaml');
      final jsonFile = directory.childFile('plugin.json');

      PluginManifest? manifest;
      if (await yamlFile.exists()) {
        final content = await yamlFile.readAsString();
        // Simple YAML-like parsing for plugin.yaml
        final data = _parseSimpleYaml(content);
        manifest = PluginManifest.fromYaml(data, dir: dir);
      } else if (await jsonFile.exists()) {
        final content = await jsonFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        manifest = PluginManifest.fromJson(json, dir: dir);
      }

      if (manifest != null) {
        logger.info(
          'Discovered plugin manifest: ${manifest.name} '
          'v${manifest.version} at $dir',
        );

        // TODO(G.5): Isolate-based loading.
        // For now, we can only discover manifest metadata.  To actually load
        // the plugin's Dart code, the user must register it programmatically
        // via [registerPlugin] or the plugin must be a compiled package
        // dependency that registers itself.
        //
        // Future implementation:
        //   1. Spawn isolate with the entry point file (manifest.entryPoint)
        //   2. Call a well-known top-level function (e.g. `createPlugin()`)
        //   3. Receive the ConfigrPlugin instance via SendPort
        //   4. Add it to the plugins list
      }
    }

    return plugins;
  }

  /// Call [ConfigrPlugin.registerBlocks] for every discovered plugin.
  Future<void> registerAllPlugins(
    i3.ConfigProcessor processor, {
    EventBus? eventBus,
  }) async {
    final plugins = await discoverPlugins();
    for (final plugin in plugins) {
      if (plugin is LuaPlugin) {
        plugin.setPluginContext(
          PluginContext.fromConfigContext(processor.context).toMap(),
        );
      }
      await plugin.initialize();
      plugin.registerBlocks(processor, eventBus: eventBus);
    }
  }

  // ---------------------------------------------------------------------------
  // Simple YAML parser for plugin.yaml manifests
  // ---------------------------------------------------------------------------

  /// Parses a simple key-value YAML-like format suitable for plugin manifests.
  ///
  /// Only supports top-level keys in the form:
  /// ```yaml
  /// name: my-plugin
  /// version: 1.0.0
  /// description: "A plugin"
  /// entry_point: lib/main.dart
  /// ```
  Map<String, dynamic> _parseSimpleYaml(String content) {
    final result = <String, dynamic>{};
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final colonPos = trimmed.indexOf(':');
      if (colonPos <= 0) continue;
      final key = trimmed.substring(0, colonPos).trim();
      var value = trimmed.substring(colonPos + 1).trim();
      // Remove surrounding quotes
      if (value.startsWith('"') && value.endsWith('"')) {
        value = value.substring(1, value.length - 1);
      } else if (value.startsWith("'") && value.endsWith("'")) {
        value = value.substring(1, value.length - 1);
      }
      result[key] = value;
    }
    return result;
  }
}
