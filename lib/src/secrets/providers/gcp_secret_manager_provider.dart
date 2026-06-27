import 'dart:io' show Process;

import 'package:configr/src/secrets/secret_provider.dart';

class GcpSecretManagerProvider extends SecretProvider {
  const GcpSecretManagerProvider();

  @override
  Future<String?> get(String project, String key, String? profile) async {
    final secretName = profile != null && profile.isNotEmpty
        ? 'projects/$profile/secrets/$key/versions/latest'
        : '$key/versions/latest';
    try {
      final result = await Process.run(
        'gcloud',
        ['secrets', 'versions', 'access', 'latest', '--secret', secretName],
      );
      if (result.exitCode != 0) return null;
      return (result.stdout as String).trimRight();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> checkDependencies() async {
    try {
      final result = await Process.run('gcloud', ['--version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
