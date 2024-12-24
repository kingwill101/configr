import 'dart:io';

import 'package:configr/models/command.dart';
import 'package:configr/utils/privellage_escallation.dart';

class CommandExecutor {
  static Future<ProcessResult> execute(
      Command command, PrivilegeEscalation privilegeEscalation) async {
    if (command.command == null || command.command!.isEmpty) {
      throw Exception("missing command");
    }

    final result = await privilegeEscalation.runWithElevatedPrivileges(
      command.command!,
      command.parameters,
    );

    if (result.exitCode != 0) {
      throw Exception('Command failed: ${result.stderr}');
    }

    print(result.stdout);
    return result;
  }
}
