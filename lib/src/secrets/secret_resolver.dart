import 'secret_provider.dart';
import 'secret_providers.dart';

class SecretResolver {
  final SecretProviders _providers;

  SecretResolver(this._providers);

  SecretProviders get providers => _providers;

  Future<String?> resolve(
    String uriString, {
    Map<String, String>? aliases,
  }) async {
    return _providers.resolve(uriString, aliases: aliases);
  }

  Future<dynamic> resolveWithSensitivity(
    String uriString, {
    Map<String, String>? aliases,
    bool markSensitive = true,
  }) async {
    final value = await resolve(uriString, aliases: aliases);
    if (value == null) return null;
    if (markSensitive) return SensitiveValue(value);
    return value;
  }
}
