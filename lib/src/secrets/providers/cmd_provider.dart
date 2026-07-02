import 'dart:io' show Platform, Process;

import 'package:configr/src/secrets/secret_provider.dart';
import 'package:configr/src/utils/shell_type.dart';

class CmdProvider extends SecretProvider {
  final Map<String, String> _environment;

  const CmdProvider([this._environment = const {}]);

  @override
  Future<String?> get(String project, String key, String? profile) async {
    final command = Uri.decodeFull(key);
    if (command.trim().isEmpty) return null;
    try {
      final result = Platform.isWindows
          ? await Process.run(
              ShellType.cmd.defaultExecutable,
              ShellType.cmd.scriptArgs(command),
              environment: _environment.isNotEmpty ? _environment : null,
            )
          : await Process.run(
              ShellType.sh.defaultExecutable,
              ShellType.sh.scriptArgs(command),
              environment: _environment.isNotEmpty ? _environment : null,
            );
      if (result.exitCode != 0) return null;
      return (result.stdout as String).trimRight();
    } catch (_) {
      return null;
    }
  }
}
