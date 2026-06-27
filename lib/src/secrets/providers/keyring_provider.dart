import 'dart:io' show Process;

import 'package:configr/src/secrets/secret_provider.dart';

class KeyringProvider extends SecretProvider {
  const KeyringProvider();

  @override
  Future<String?> get(String project, String key, String? profile) async {
    try {
      final result = await Process.run(
        'secret-tool',
        ['lookup', 'service', project, 'account', key],
      );
      if (result.exitCode != 0) return null;
      return (result.stdout as String).trimRight();
    } catch (_) {
      return null;
    }
  }
}
