import 'dart:io' show File;

import 'package:configr/src/secrets/secret_provider.dart';

class FileProvider extends SecretProvider {
  const FileProvider();

  @override
  Future<String?> get(String project, String key, String? profile) async {
    final path = key.startsWith('/') ? key : '/$key';
    final file = File(path);
    if (!await file.exists()) return null;
    final content = await file.readAsString();
    return content.trimRight();
  }
}
