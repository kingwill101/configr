import 'dart:io' show Process;

import 'package:configr/src/secrets/secret_provider.dart';

class DopplerProvider extends SecretProvider {
  const DopplerProvider();

  @override
  Future<String?> get(String project, String key, String? profile) async {
    final args = ['secrets', 'get', key, '--plain'];
    if (project.isNotEmpty) {
      args.addAll(['--project', project]);
    }
    if (profile != null && profile.isNotEmpty) {
      args.addAll(['--config', profile]);
    }
    try {
      final result = await Process.run('doppler', args);
      if (result.exitCode != 0) return null;
      return (result.stdout as String).trimRight();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> checkDependencies() async {
    try {
      final result = await Process.run('doppler', ['--version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
