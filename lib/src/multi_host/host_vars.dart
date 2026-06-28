import 'dart:convert';

import 'package:file/file.dart';
import 'package:file/local.dart';

/// Provides cross-host variable access (hostvars) for multi-host configs.
///
/// Reads per-host fact files written by `gather_facts { destination = "..." }`
/// and makes them available as a map keyed by host name.
///
/// Usage in templates:
/// ```i3
/// template {
///   source = "/app/config.template"
///   destination = "/app/config.json"
///   variables = {
///     db_host = "{{ hostvars['db-01'].address }}"
///   }
/// }
/// ```
class HostVars {
  final String factsDir;
  final FileSystem fs;

  HostVars({this.factsDir = '.configr/facts', FileSystem? fs})
      : fs = fs ?? LocalFileSystem();

  /// Load facts for a single host.
  ///
  /// Returns an empty map if the fact file doesn't exist or can't be parsed.
  Map<String, dynamic> factsFor(String hostName) {
    final file = fs.file('$factsDir/$hostName.json');
    if (!file.existsSync()) return {};
    try {
      final content = file.readAsStringSync();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Load facts for all discovered hosts.
  ///
  /// Returns a map of host name → fact map.
  Map<String, Map<String, dynamic>> allFacts() {
    final dir = fs.directory(factsDir);
    if (!dir.existsSync()) return {};
    final result = <String, Map<String, dynamic>>{};
    for (final entry in dir.listSync()) {
      if (entry is File && entry.path.endsWith('.json')) {
        final name = entry.basename.replaceAll('.json', '');
        try {
          final content = entry.readAsStringSync();
          result[name] = jsonDecode(content) as Map<String, dynamic>;
        } catch (_) {
          // skip unreadable files
        }
      }
    }
    return result;
  }

  /// Check if facts exist for a host.
  bool hasFacts(String hostName) {
    return fs.file('$factsDir/$hostName.json').existsSync();
  }

  /// Get a specific fact value for a host.
  ///
  /// Returns `null` if the host or fact doesn't exist.
  dynamic factFor(String hostName, String factName) {
    return factsFor(hostName)[factName];
  }

  /// Register this HostVars instance in the processor context
  /// so templates and blocks can use `hostvars['name']`.
  void registerInContext(Map<String, dynamic> context) {
    context['hostvars'] = <String, Map<String, dynamic>>{
      // Lazily populated on access via a wrapper
    };

    // We store a reference to the HostVars instance
    // Blocks/templates can access it as:
    //   hostvars.get('web-01')['os_family']
    context['_hostVarsService'] = this;
  }
}
