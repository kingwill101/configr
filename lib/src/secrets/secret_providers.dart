import 'secret_provider.dart';

class SecretProviders {
  final Map<String, SecretProvider Function(Uri)> _factories = {};
  final Map<String, SecretProvider> _instances = {};

  void register(String scheme, SecretProvider Function(Uri) factory) {
    _factories[scheme] = factory;
  }

  SecretProvider? get(String scheme) => _instances[scheme];

  Future<String?> resolve(
    String uriString, {
    Map<String, String>? aliases,
  }) async {
    var effectiveUri = uriString;
    final scheme = _extractScheme(effectiveUri);
    if (scheme == null) return null;

    var resolvedScheme = scheme;
    if (aliases?.containsKey(scheme) == true) {
      final aliasTarget = aliases![scheme]!;
      final aliasScheme = _extractScheme(aliasTarget);
      if (aliasScheme != null) {
        resolvedScheme = aliasScheme;
        effectiveUri =
            '$aliasScheme://${effectiveUri.substring(scheme.length + 3)}';
      }
    }

    final uri = Uri.tryParse(effectiveUri);
    if (uri == null) return null;

    final provider = _providerFor(resolvedScheme, uri);
    if (provider == null) return null;

    final String project;
    if (scheme == 'dotenv') {
      // On Windows, dotenv://C:/path/file parses with host='c' and path='/path/file'.
      // Reconstruct the full path by prepending the drive letter.
      final host = uri.host;
      project = (host.length == 1 &&
              RegExp(r'^[a-zA-Z]$').hasMatch(host))
          ? '$host:${uri.path}'
          : uri.path;
    } else {
      project = uri.host.isNotEmpty ? uri.host : uri.path;
    }
    final key = uri.queryParameters['name'] ?? _extractKey(uriString);
    final profile = uri.queryParameters['profile'];
    return provider.get(project, key, profile);
  }

  String _extractKey(String uriString) {
    final idx = uriString.indexOf('://');
    if (idx < 0) return uriString;
    final after = uriString.substring(idx + 3);
    final qIdx = after.indexOf('?');
    return qIdx < 0 ? after : after.substring(0, qIdx);
  }

  String? _extractScheme(String uriString) {
    final idx = uriString.indexOf('://');
    if (idx < 0) return null;
    return uriString.substring(0, idx);
  }

  SecretProvider? _providerFor(String scheme, Uri uri) {
    final instance = _instances[scheme];
    if (instance != null) return instance;
    final factory = _factories[scheme];
    if (factory == null) return null;
    final created = factory(uri);
    _instances[scheme] = created;
    return created;
  }
}
