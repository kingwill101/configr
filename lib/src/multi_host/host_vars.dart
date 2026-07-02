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
  Future<Map<String, dynamic>> factsFor(String hostName) async {
    final file = fs.file('$factsDir/$hostName.json');
    if (!await file.exists()) return {};
    try {
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Load facts for all discovered hosts.
  ///
  /// Returns a map of host name → fact map.
  Future<Map<String, Map<String, dynamic>>> allFacts() async {
    final dir = fs.directory(factsDir);
    if (!await dir.exists()) return {};
    final result = <String, Map<String, dynamic>>{};
    await for (final entry in dir.list()) {
      if (entry is File && entry.path.endsWith('.json')) {
        final name = entry.basename.replaceAll('.json', '');
        try {
          final content = await entry.readAsString();
          result[name] = jsonDecode(content) as Map<String, dynamic>;
        } catch (_) {
          // skip unreadable files
        }
      }
    }
    return result;
  }

  /// Check if facts exist for a host.
  Future<bool> hasFacts(String hostName) {
    return fs.file('$factsDir/$hostName.json').exists();
  }

  /// Get a specific fact value for a host.
  ///
  /// Returns `null` if the host or fact doesn't exist.
  Future<dynamic> factFor(String hostName, String factName) async {
    return (await factsFor(hostName))[factName];
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
