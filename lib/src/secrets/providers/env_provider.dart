import 'dart:io' show Platform;

import 'package:configr/src/secrets/secret_provider.dart';

class EnvProvider extends SecretProvider {
  const EnvProvider();

  @override
  Future<String?> get(String project, String key, String? profile) async {
    return Platform.environment[key];
  }
}
