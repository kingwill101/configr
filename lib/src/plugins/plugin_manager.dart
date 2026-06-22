import 'dart:async';
import 'dart:isolate';

import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:file/file.dart';

/// Plugin metadata and configuration
class PluginMetadata {
  final String name;
  final String version;
  final String description;
  final String author;
  final List<String> dependencies;
  final Map<String, dynamic> configuration;
  final String? entryPoint;

  const PluginMetadata({
    required this.name,
    required this.version,
    required this.description,
    required this.author,
    this.dependencies = const [],
    this.configuration = const {},
    this.entryPoint,
  });

  factory PluginMetadata.fromMap(Map<String, dynamic> map) {
    return PluginMetadata(
      name: map['name'] as String,
      version: map['version'] as String,
      description: map['description'] as String,
      author: map['author'] as String,
      dependencies: List<String>.from(map['dependencies'] ?? []),
      configuration: Map<String, dynamic>.from(map['configuration'] ?? {}),
      entryPoint: map['entryPoint'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'version': version,
      'description': description,
      'author': author,
      'dependencies': dependencies,
      'configuration': configuration,
      'entryPoint': entryPoint,
    };
  }
}

/// Plugin lifecycle states
enum PluginState {
  unloaded,
  loading,
  loaded,
  initializing,
  initialized,
  starting,
  running,
  stopping,
  stopped,
  error,
}

/// Plugin instance with lifecycle management
class PluginInstance {
  final PluginMetadata metadata;
  final String id;
  PluginState _state = PluginState.unloaded;
  dynamic _plugin;
  Isolate? _isolate;
  SendPort? _sendPort;
  final List<String> _errors = [];

  PluginInstance({required this.metadata, required this.id});

  /// Current plugin state
  PluginState get state => _state;

  /// Plugin instance
  dynamic get plugin => _plugin;

  /// Isolate for isolated plugins
  Isolate? get isolate => _isolate;

  /// Communication port
  SendPort? get sendPort => _sendPort;

  /// List of errors
  List<String> get errors => List.unmodifiable(_errors);

  /// Check if plugin is running
  bool get isRunning => _state == PluginState.running;

  /// Check if plugin is loaded
  bool get isLoaded => _state.index >= PluginState.loaded.index;

  /// Check if plugin has errors
  bool get hasErrors => _errors.isNotEmpty;

  /// Set plugin state
  void _setState(PluginState newState) {
    _state = newState;
  }

  /// Add error
  void _addError(String error) {
    _errors.add(error);
  }
}

/// Plugin interface that all plugins must implement
abstract class Plugin {
  /// Plugin metadata
  PluginMetadata get metadata;

  /// Initialize the plugin
  Future<void> initialize(Map<String, dynamic> config);

  /// Start the plugin
  Future<void> start();

  /// Stop the plugin
  Future<void> stop();

  /// Dispose the plugin
  Future<void> dispose();

  /// Handle events from the event bus
  void onEvent(ModuleEvent event);

  /// Get plugin health status
  Map<String, dynamic> getHealthStatus();
}

/// Plugin manager for loading and managing plugins
class PluginManager {
  final EventBus _eventBus;
  final FileSystem? fileSystem;

  PluginManager({EventBus? eventBus, this.fileSystem})
    : _eventBus = eventBus ?? EventBus();

  final Map<String, PluginInstance> _plugins = {};
  final Map<String, PluginMetadata> _availablePlugins = {};
  final List<String> _pluginPaths = [];
  bool _initialized = false;

  /// Get all loaded plugins
  Map<String, PluginInstance> get plugins => Map.unmodifiable(_plugins);

  /// Get all available plugins
  Map<String, PluginMetadata> get availablePlugins =>
      Map.unmodifiable(_availablePlugins);

  /// Check if plugin manager is initialized
  bool get isInitialized => _initialized;

  /// Initialize the plugin manager
  Future<void> initialize({List<String>? pluginPaths}) async {
    if (_initialized) return;

    _pluginPaths.addAll(pluginPaths ?? []);
    await _scanForPlugins();
    _initialized = true;

    _eventBus.emit(
      PluginEvent(
        pluginName: 'PluginManager',
        action: 'initialized',
        details: {'pluginCount': _availablePlugins.length},
      ),
    );
  }

  /// Scan for available plugins
  Future<void> _scanForPlugins() async {
    // TODO: Implement plugin discovery from filesystem
    // This would scan plugin directories for plugin.json files
    // and load plugin metadata
  }

  /// Load a plugin by name
  Future<PluginInstance> loadPlugin(
    String name, {
    Map<String, dynamic>? config,
    bool isolated = false,
  }) async {
    if (!_initialized) {
      throw ActionFailedException(
        'Plugin manager not initialized',
        moduleId: 'PluginManager',
        correlationId: null,
      );
    }

    if (_plugins.containsKey(name)) {
      throw ActionFailedException(
        'Plugin already loaded: $name',
        moduleId: 'PluginManager',
        correlationId: null,
      );
    }

    final metadata = _availablePlugins[name];
    if (metadata == null) {
      throw ActionFailedException(
        'Plugin not found: $name',
        moduleId: 'PluginManager',
        correlationId: null,
      );
    }

    final pluginId = '${name}_${DateTime.now().millisecondsSinceEpoch}';
    final instance = PluginInstance(metadata: metadata, id: pluginId);

    try {
      instance._setState(PluginState.loading);
      _plugins[name] = instance;

      _eventBus.emit(
        PluginEvent(
          pluginName: name,
          action: 'loading',
          moduleId: 'PluginManager',
        ),
      );

      // Load plugin dependencies first
      await _loadDependencies(metadata.dependencies);

      // Load the plugin
      if (isolated) {
        await _loadIsolatedPlugin(instance, config ?? {});
      } else {
        await _loadInProcessPlugin(instance, config ?? {});
      }

      instance._setState(PluginState.loaded);

      _eventBus.emit(
        PluginEvent(
          pluginName: name,
          action: 'loaded',
          moduleId: 'PluginManager',
        ),
      );

      return instance;
    } catch (e) {
      instance._setState(PluginState.error);
      instance._addError(e.toString());
      _plugins.remove(name);

      _eventBus.emit(
        PluginEvent(
          pluginName: name,
          action: 'load_failed',
          moduleId: 'PluginManager',
          details: {'error': e.toString()},
        ),
      );

      rethrow;
    }
  }

  /// Load plugin dependencies
  Future<void> _loadDependencies(List<String> dependencies) async {
    for (final dep in dependencies) {
      if (!_plugins.containsKey(dep)) {
        await loadPlugin(dep);
      }
    }
  }

  /// Load plugin in the same process
  Future<void> _loadInProcessPlugin(
    PluginInstance instance,
    Map<String, dynamic> config,
  ) async {
    // TODO: Implement in-process plugin loading
    // This would dynamically load Dart code and instantiate the plugin
  }

  /// Load plugin in an isolated process
  Future<void> _loadIsolatedPlugin(
    PluginInstance instance,
    Map<String, dynamic> config,
  ) async {
    // TODO: Implement isolated plugin loading
    // This would create an isolate and load the plugin there
  }

  /// Initialize a loaded plugin
  Future<void> initializePlugin(String name) async {
    final instance = _plugins[name];
    if (instance == null) {
      throw ActionFailedException(
        'Plugin not loaded: $name',
        moduleId: 'PluginManager',
        correlationId: null,
      );
    }

    try {
      instance._setState(PluginState.initializing);

      _eventBus.emit(
        PluginEvent(
          pluginName: name,
          action: 'initializing',
          moduleId: 'PluginManager',
        ),
      );

      // TODO: Call plugin.initialize() with configuration

      instance._setState(PluginState.initialized);

      _eventBus.emit(
        PluginEvent(
          pluginName: name,
          action: 'initialized',
          moduleId: 'PluginManager',
        ),
      );
    } catch (e) {
      instance._setState(PluginState.error);
      instance._addError(e.toString());

      _eventBus.emit(
        PluginEvent(
          pluginName: name,
          action: 'initialize_failed',
          moduleId: 'PluginManager',
          details: {'error': e.toString()},
        ),
      );

      rethrow;
    }
  }

  /// Start a plugin
  Future<void> startPlugin(String name) async {
    final instance = _plugins[name];
    if (instance == null) {
      throw ActionFailedException(
        'Plugin not loaded: $name',
        moduleId: 'PluginManager',
        correlationId: null,
      );
    }

    try {
      instance._setState(PluginState.starting);

      _eventBus.emit(
        PluginEvent(
          pluginName: name,
          action: 'starting',
          moduleId: 'PluginManager',
        ),
      );

      // TODO: Call plugin.start()

      instance._setState(PluginState.running);

      _eventBus.emit(
        PluginEvent(
          pluginName: name,
          action: 'started',
          moduleId: 'PluginManager',
        ),
      );
    } catch (e) {
      instance._setState(PluginState.error);
      instance._addError(e.toString());

      _eventBus.emit(
        PluginEvent(
          pluginName: name,
          action: 'start_failed',
          moduleId: 'PluginManager',
          details: {'error': e.toString()},
        ),
      );

      rethrow;
    }
  }

  /// Stop a plugin
  Future<void> stopPlugin(String name) async {
    final instance = _plugins[name];
    if (instance == null) {
      throw ActionFailedException(
        'Plugin not loaded: $name',
        moduleId: 'PluginManager',
        correlationId: null,
      );
    }

    try {
      instance._setState(PluginState.stopping);

      _eventBus.emit(
        PluginEvent(
          pluginName: name,
          action: 'stopping',
          moduleId: 'PluginManager',
        ),
      );

      // TODO: Call plugin.stop()

      instance._setState(PluginState.stopped);

      _eventBus.emit(
        PluginEvent(
          pluginName: name,
          action: 'stopped',
          moduleId: 'PluginManager',
        ),
      );
    } catch (e) {
      instance._setState(PluginState.error);
      instance._addError(e.toString());

      _eventBus.emit(
        PluginEvent(
          pluginName: name,
          action: 'stop_failed',
          moduleId: 'PluginManager',
          details: {'error': e.toString()},
        ),
      );

      rethrow;
    }
  }

  /// Unload a plugin
  Future<void> unloadPlugin(String name) async {
    final instance = _plugins[name];
    if (instance == null) {
      throw ActionFailedException(
        'Plugin not loaded: $name',
        moduleId: 'PluginManager',
        correlationId: null,
      );
    }

    try {
      // Stop plugin if running
      if (instance.isRunning) {
        await stopPlugin(name);
      }

      _eventBus.emit(
        PluginEvent(
          pluginName: name,
          action: 'unloading',
          moduleId: 'PluginManager',
        ),
      );

      // TODO: Call plugin.dispose() and cleanup

      _plugins.remove(name);

      _eventBus.emit(
        PluginEvent(
          pluginName: name,
          action: 'unloaded',
          moduleId: 'PluginManager',
        ),
      );
    } catch (e) {
      instance._addError(e.toString());

      _eventBus.emit(
        PluginEvent(
          pluginName: name,
          action: 'unload_failed',
          moduleId: 'PluginManager',
          details: {'error': e.toString()},
        ),
      );

      rethrow;
    }
  }

  /// Get plugin health status
  Map<String, dynamic> getPluginHealth(String name) {
    final instance = _plugins[name];
    if (instance == null) {
      throw ActionFailedException(
        'Plugin not loaded: $name',
        moduleId: 'PluginManager',
        correlationId: null,
      );
    }

    return {
      'name': name,
      'state': instance.state.name,
      'hasErrors': instance.hasErrors,
      'errors': instance.errors,
      'isRunning': instance.isRunning,
    };
  }

  /// Get all plugin health statuses
  Map<String, Map<String, dynamic>> getAllPluginHealth() {
    final health = <String, Map<String, dynamic>>{};
    for (final name in _plugins.keys) {
      health[name] = getPluginHealth(name);
    }
    return health;
  }

  /// Dispose the plugin manager
  Future<void> dispose() async {
    // Stop and unload all plugins
    final pluginNames = List<String>.from(_plugins.keys);
    for (final name in pluginNames) {
      try {
        await unloadPlugin(name);
      } catch (e) {
        // Log error but continue with other plugins
        _eventBus.emit(
          PluginEvent(
            pluginName: name,
            action: 'dispose_error',
            moduleId: 'PluginManager',
            details: {'error': e.toString()},
          ),
        );
      }
    }

    _plugins.clear();
    _availablePlugins.clear();
    _pluginPaths.clear();
    _initialized = false;
  }
}
