import 'package:i3config/i3config_v2.dart' as i3;

/// Precedence tiers for variable resolution.
///
/// Higher priority values win over lower ones.
enum PrecedenceLayer {
  facts(1),
  secrets(2),
  groupVars(3),
  hostVars(4),
  cliVars(5);

  const PrecedenceLayer(this.priority);
  final int priority;
}

/// A variable source with an associated precedence layer.
class VariableSource {
  final PrecedenceLayer layer;
  final Map<String, dynamic> variables;

  const VariableSource(this.layer, this.variables);
}

/// Implements the Ansible-style variable precedence chain as an i3config
/// [i3.VariableMiddleware].
///
/// Resolution order (highest to lowest):
/// 1. CLI vars (`--var key=value`)
/// 2. Host vars (from inventory host definitions)
/// 3. Group vars (from inventory group definitions)
/// 4. Secrets (resolved by secrets block)
/// 5. System facts (from gather_facts block)
///
/// Variables set via config file assignments and `set_fact` blocks go into the
/// normal i3 context and are checked after all precedence layers.
class VariablePrecedence implements i3.VariableMiddleware {
  final List<VariableSource> _sources = [];

  /// Register a variable source at the given precedence layer.
  void addSource(PrecedenceLayer layer, Map<String, dynamic> variables) {
    _sources.add(VariableSource(layer, variables));
  }

  /// Bulk-register multiple sources.
  void addSources(Iterable<VariableSource> sources) {
    _sources.addAll(sources);
  }

  /// Remove all sources at the given layer.
  void removeLayer(PrecedenceLayer layer) {
    _sources.removeWhere((s) => s.layer == layer);
  }

  /// Replace all sources at the given layer (e.g. after facts update).
  void setLayer(PrecedenceLayer layer, Map<String, dynamic> variables) {
    removeLayer(layer);
    _sources.add(VariableSource(layer, variables));
  }

  /// Clear all registered sources.
  void clear() => _sources.clear();

  /// Look up a variable across all layers.
  ///
  /// Returns the value from the highest-priority layer that has it, or `null`
  /// if none of the layers contain the variable.
  dynamic lookup(String name) {
    VariableSource? best;
    for (final source in _sources) {
      if (source.variables.containsKey(name)) {
        if (best == null || source.layer.priority > best.layer.priority) {
          best = source;
        }
      }
    }
    return best?.variables[name];
  }

  @override
  dynamic onSet(String name, dynamic value, i3.Context context) => value;

  @override
  dynamic onGet(String name, dynamic value, i3.Context context) {
    final overridden = lookup(name);
    return overridden ?? value;
  }

  @override
  String? onExpand(String text, i3.Context context) => text;
}
