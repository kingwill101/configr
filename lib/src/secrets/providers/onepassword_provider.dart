import 'dart:io' show Process;

import 'package:configr/src/secrets/secret_provider.dart';

class OnePasswordProvider extends SecretProvider {
  const OnePasswordProvider();

  @override
  Future<String?> get(String project, String key, String? profile) async {
    final parts = key.split('/');
    if (parts.length < 2) return null;
    final itemName = parts[0];
    final field = parts.sublist(1).join('/');
    final args = ['read', '-o', 'op://$project/$itemName/$field'];
    if (profile != null && profile.isNotEmpty) {
      args.insertAll(0, ['--account', profile]);
    }
    try {
      final result = await Process.run('op', args);
      if (result.exitCode != 0) return null;
      return (result.stdout as String).trimRight();
    } catch (_) {
      return null;
    }
  }
}
