import 'package:configr/exceptions.dart';

/// Plugin dependency information
class PluginDependency {
  final String name;
  final String version;
  final bool optional;

  const PluginDependency({
    required this.name,
    required this.version,
    this.optional = false,
  });

  factory PluginDependency.fromMap(Map<String, dynamic> map) {
    return PluginDependency(
      name: map['name'] as String,
      version: map['version'] as String,
      optional: map['optional'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'version': version,
      'optional': optional,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PluginDependency &&
        other.name == name &&
        other.version == version &&
        other.optional == optional;
  }

  @override
  int get hashCode => Object.hash(name, version, optional);
}

/// Plugin capability definition
class PluginCapability {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  const PluginCapability({
    required this.name,
    required this.description,
    this.parameters = const {},
  });

  factory PluginCapability.fromMap(Map<String, dynamic> map) {
    return PluginCapability(
      name: map['name'] as String,
      description: map['description'] as String,
      parameters: Map<String, dynamic>.from(map['parameters'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'parameters': parameters,
    };
  }
}

/// Plugin registry entry
class PluginRegistryEntry {
  final String name;
  final String version;
  final String description;
  final String author;
  final List<PluginDependency> dependencies;
  final List<PluginCapability> capabilities;
  final Map<String, dynamic> configuration;
  final String? entryPoint;
  final String? sourcePath;
  final DateTime registeredAt;
  final bool enabled;

  const PluginRegistryEntry({
    required this.name,
    required this.version,
    required this.description,
    required this.author,
    this.dependencies = const [],
    this.capabilities = const [],
    this.configuration = const {},
    this.entryPoint,
    this.sourcePath,
    required this.registeredAt,
    this.enabled = true,
  });

  factory PluginRegistryEntry.fromMap(Map<String, dynamic> map) {
    return PluginRegistryEntry(
      name: map['name'] as String,
      version: map['version'] as String,
      description: map['description'] as String,
      author: map['author'] as String,
      dependencies: (map['dependencies'] as List<dynamic>?)
          ?.map((d) => PluginDependency.fromMap(d as Map<String, dynamic>))
          .toList() ?? [],
      capabilities: (map['capabilities'] as List<dynamic>?)
          ?.map((c) => PluginCapability.fromMap(c as Map<String, dynamic>))
          .toList() ?? [],
      configuration: Map<String, dynamic>.from(map['configuration'] ?? {}),
      entryPoint: map['entryPoint'] as String?,
      sourcePath: map['sourcePath'] as String?,
      registeredAt: DateTime.parse(map['registeredAt'] as String),
      enabled: map['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'version': version,
      'description': description,
      'author': author,
      'dependencies': dependencies.map((d) => d.toMap()).toList(),
      'capabilities': capabilities.map((c) => c.toMap()).toList(),
      'configuration': configuration,
      'entryPoint': entryPoint,
      'sourcePath': sourcePath,
      'registeredAt': registeredAt.toIso8601String(),
      'enabled': enabled,
    };
  }

  /// Create a copy with updated fields
  PluginRegistryEntry copyWith({
    String? name,
    String? version,
    String? description,
    String? author,
    List<PluginDependency>? dependencies,
    List<PluginCapability>? capabilities,
    Map<String, dynamic>? configuration,
    String? entryPoint,
    String? sourcePath,
    DateTime? registeredAt,
    bool? enabled,
  }) {
    return PluginRegistryEntry(
      name: name ?? this.name,
      version: version ?? this.version,
      description: description ?? this.description,
      author: author ?? this.author,
      dependencies: dependencies ?? this.dependencies,
      capabilities: capabilities ?? this.capabilities,
      configuration: configuration ?? this.configuration,
      entryPoint: entryPoint ?? this.entryPoint,
      sourcePath: sourcePath ?? this.sourcePath,
      registeredAt: registeredAt ?? this.registeredAt,
      enabled: enabled ?? this.enabled,
    );
  }
}

/// Plugin registry for managing plugin metadata and discovery
class PluginRegistry {
  static final PluginRegistry _instance = PluginRegistry._internal();

  factory PluginRegistry() => _instance;

  PluginRegistry._internal();

  final Map<String, PluginRegistryEntry> _plugins = {};
  final Map<String, List<String>> _dependencies = {};
  final Map<String, List<String>> _dependents = {};

  /// Get all registered plugins
  Map<String, PluginRegistryEntry> get plugins => Map.unmodifiable(_plugins);

  /// Get enabled plugins only
  Map<String, PluginRegistryEntry> get enabledPlugins {
    return Map.fromEntries(
      _plugins.entries.where((entry) => entry.value.enabled),
    );
  }

  /// Register a plugin
  void registerPlugin(PluginRegistryEntry entry) {
    _plugins[entry.name] = entry;
    _updateDependencyGraph(entry);
  }

  /// Unregister a plugin
  void unregisterPlugin(String name) {
    final entry = _plugins.remove(name);
    if (entry != null) {
      _removeFromDependencyGraph(entry);
    }
  }

  /// Get plugin by name
  PluginRegistryEntry? getPlugin(String name) {
    return _plugins[name];
  }

  /// Check if plugin is registered
  bool isRegistered(String name) {
    return _plugins.containsKey(name);
  }

  /// Enable a plugin
  void enablePlugin(String name) {
    final entry = _plugins[name];
    if (entry != null) {
      _plugins[name] = entry.copyWith(enabled: true);
    }
  }

  /// Disable a plugin
  void disablePlugin(String name) {
    final entry = _plugins[name];
    if (entry != null) {
      _plugins[name] = entry.copyWith(enabled: false);
    }
  }

  /// Get plugin dependencies
  List<String> getDependencies(String name) {
    return _dependencies[name] ?? [];
  }

  /// Get plugins that depend on this plugin
  List<String> getDependents(String name) {
    return _dependents[name] ?? [];
  }

  /// Resolve plugin load order based on dependencies
  List<String> resolveLoadOrder(List<String> pluginNames) {
    final resolved = <String>[];
    final visited = <String>{};
    final visiting = <String>{};

    void visit(String name) {
      if (visiting.contains(name)) {
        throw ActionFailedException(
          'Circular dependency detected involving plugin: $name',
          moduleId: 'PluginRegistry',
          correlationId: null,
        );
      }

      if (visited.contains(name)) return;

      visiting.add(name);

      final dependencies = getDependencies(name);
      for (final dep in dependencies) {
        if (pluginNames.contains(dep)) {
          visit(dep);
        }
      }

      visiting.remove(name);
      visited.add(name);
      resolved.add(name);
    }

    for (final name in pluginNames) {
      if (!visited.contains(name)) {
        visit(name);
      }
    }

    return resolved;
  }

  /// Validate plugin dependencies
  void validateDependencies(List<String> pluginNames) {
    for (final name in pluginNames) {
      final entry = _plugins[name];
      if (entry == null) {
        throw ActionFailedException(
          'Plugin not found: $name',
          moduleId: 'PluginRegistry',
          correlationId: null,
        );
      }

      for (final dep in entry.dependencies) {
        if (!dep.optional && !pluginNames.contains(dep.name)) {
          throw ActionFailedException(
            'Required dependency not found: ${dep.name} for plugin: $name',
            moduleId: 'PluginRegistry',
            correlationId: null,
          );
        }

        final depEntry = _plugins[dep.name];
        if (depEntry != null && !_isVersionCompatible(depEntry.version, dep.version)) {
          throw ActionFailedException(
            'Version mismatch for dependency: ${dep.name} (required: ${dep.version}, found: ${depEntry.version})',
            moduleId: 'PluginRegistry',
            correlationId: null,
          );
        }
      }
    }
  }

  /// Check if version is compatible
  bool _isVersionCompatible(String installed, String required) {
    // Simple version compatibility check
    // In a real implementation, this would use semantic versioning
    return installed == required || installed.startsWith(required.split('.')[0]);
  }

  /// Update dependency graph
  void _updateDependencyGraph(PluginRegistryEntry entry) {
    _dependencies[entry.name] = entry.dependencies
        .where((dep) => !dep.optional)
        .map((dep) => dep.name)
        .toList();

    for (final dep in entry.dependencies) {
      if (!dep.optional) {
        _dependents.putIfAbsent(dep.name, () => []).add(entry.name);
      }
    }
  }

  /// Remove from dependency graph
  void _removeFromDependencyGraph(PluginRegistryEntry entry) {
    _dependencies.remove(entry.name);

    for (final dep in entry.dependencies) {
      if (!dep.optional) {
        _dependents[dep.name]?.remove(entry.name);
        if (_dependents[dep.name]?.isEmpty ?? false) {
          _dependents.remove(dep.name);
        }
      }
    }

    // Remove this plugin from all dependents
    for (final dependents in _dependents.values) {
      dependents.remove(entry.name);
    }
  }

  /// Search plugins by capability
  List<PluginRegistryEntry> searchByCapability(String capability) {
    return _plugins.values
        .where((entry) => entry.capabilities.any((cap) => cap.name == capability))
        .toList();
  }

  /// Search plugins by author
  List<PluginRegistryEntry> searchByAuthor(String author) {
    return _plugins.values
        .where((entry) => entry.author == author)
        .toList();
  }

  /// Get plugin statistics
  Map<String, dynamic> getStatistics() {
    final total = _plugins.length;
    final enabled = enabledPlugins.length;
    final disabled = total - enabled;

    final capabilities = <String, int>{};
    for (final entry in _plugins.values) {
      for (final cap in entry.capabilities) {
        capabilities[cap.name] = (capabilities[cap.name] ?? 0) + 1;
      }
    }

    return {
      'total': total,
      'enabled': enabled,
      'disabled': disabled,
      'capabilities': capabilities,
      'dependencies': _dependencies.length,
    };
  }

  /// Clear all plugins
  void clear() {
    _plugins.clear();
    _dependencies.clear();
    _dependents.clear();
  }
}
