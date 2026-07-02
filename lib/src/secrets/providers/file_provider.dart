import 'dart:io' show File;

import 'package:configr/src/secrets/secret_provider.dart';
import 'package:path/path.dart' as path;

class FileProvider extends SecretProvider {
  const FileProvider();

  @override
  Future<String?> get(String project, String key, String? profile) async {
    final filePath = path.isAbsolute(key)
        ? key
        : project.isNotEmpty
        ? path.join(project, key)
        : key;
    final file = File(filePath);
    if (!await file.exists()) return null;
    final content = await file.readAsString();
    return content.trimRight();
  }
}
