import 'package:dotenv/dotenv.dart' show DotEnv;

import 'package:configr/src/secrets/secret_provider.dart';

class DotenvProvider extends SecretProvider {
  const DotenvProvider();

  @override
  Future<String?> get(String project, String key, String? profile) async {
    final env = DotEnv(quiet: true)..load([project]);
    return env[key];
  }
}
