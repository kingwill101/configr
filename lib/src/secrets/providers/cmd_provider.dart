import 'dart:io' show Platform, Process;

import 'package:configr/src/secrets/secret_provider.dart';

class CmdProvider extends SecretProvider {
  final Map<String, String> _environment;

  const CmdProvider([this._environment = const {}]);

  @override
  Future<String?> get(String project, String key, String? profile) async {
    final command = Uri.decodeFull(key);
    if (command.trim().isEmpty) return null;
    try {
      final result = Platform.isWindows
          ? await Process.run('cmd.exe', [
              '/C',
              command,
            ], environment: _environment.isNotEmpty ? _environment : null)
          : await Process.run('/bin/sh', [
              '-c',
              command,
            ], environment: _environment.isNotEmpty ? _environment : null);
      if (result.exitCode != 0) return null;
      return (result.stdout as String).trimRight();
    } catch (_) {
      return null;
    }
  }
}
