import 'dart:convert' show json;
import 'dart:io' show Process;

import 'package:configr/src/secrets/secret_provider.dart';

class AwsSecretsManagerProvider extends SecretProvider {
  const AwsSecretsManagerProvider();

  @override
  Future<String?> get(String project, String key, String? profile) async {
    final args = [
      'secretsmanager',
      'get-secret-value',
      '--secret-id',
      key,
    ];
    if (profile != null && profile.isNotEmpty) {
      args.addAll(['--profile', profile]);
    }
    try {
      final result = await Process.run('aws', args);
      if (result.exitCode != 0) return null;
      final decoded = json.decode(result.stdout as String) as Map<String, dynamic>;
      final secretString = decoded['SecretString'] as String?;
      return secretString?.trimRight();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> checkDependencies() async {
    try {
      final result = await Process.run('aws', ['--version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
