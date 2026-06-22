import 'dart:io';

import 'package:configr/src/models/command.dart';
import 'package:configr/src/utils/privilege_escalation.dart';

class CommandExecutor {
  static Future<ProcessResult> execute(
    Command command,
    PrivilegeEscalation privilegeEscalation,
  ) async {
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
