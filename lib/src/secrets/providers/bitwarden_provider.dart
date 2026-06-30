import 'dart:io' show Process;

import 'package:configr/src/secrets/secret_provider.dart';

class BitwardenProvider extends SecretProvider {
  const BitwardenProvider();

  @override
  Future<String?> get(String project, String key, String? profile) async {
    try {
      var result = await Process.run('bw', ['get', 'password', key]);
      if (result.exitCode == 0) {
        return (result.stdout as String).trimRight();
      }
      result = await Process.run('bw', ['get', 'item', key]);
      if (result.exitCode != 0) return null;
      return (result.stdout as String).trimRight();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> checkDependencies() async {
    try {
      final result = await Process.run('bw', ['--version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
