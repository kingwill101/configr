import 'dart:async';
import 'dart:io';

import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/models/command.dart';
import 'package:configr/src/security/input_sanitizer.dart';
import 'package:configr/src/security/security_manager.dart';
import 'package:configr/src/utils/execution_service.dart';
import 'package:configr/src/utils/privilege_escalation.dart';

/// Callback for streaming command output.
typedef CommandOutputHandler = void Function(String line, bool isStderr);

class CommandExecutor {
  static Future<ProcessResult> execute(
    Command command,
    PrivilegeEscalation privilegeEscalation, {
    SecurityManager? securityManager,
    InputSanitizer? inputSanitizer,
    String? workingDirectory,
    bool runInShell = false,
    bool checkExitCode = true,
    CommandOutputHandler? onOutput,
    ExecutionService? executionService,
  }) async {
    if (command.command == null || command.command!.isEmpty) {
      throw Exception("missing command");
    }

    final sanitizer = inputSanitizer ?? InputSanitizer();

    final sanitizedCommand = sanitizer.sanitizeString(
      command.command!,
      options: const SanitizationOptions(
        removeHtml: false,
        removeScripts: false,
        normalizeWhitespace: true,
        removeControlCharacters: true,
        escapeSpecialCharacters: false,
      ),
    );

    final sanitizedParams = sanitizer.sanitizeCommandArgs(command.parameters);

    final manager = securityManager ?? SecurityManager();

    if (!manager.validateInput(
      'command_execution',
      sanitizedCommand,
      SecurityContext(sessionId: command.id),
    )) {
      throw Exception('Command rejected by security policy: $sanitizedCommand');
    }

    manager.audit(
      SecurityEvent(
        moduleId: 'CommandExecutor',
        securityEventType: 'command_execution_started',
        severity: 'info',
        resource: sanitizedCommand,
        details: {'parameters': sanitizedParams, 'name': command.name},
      ),
    );

    final exec = executionService ?? const LocalExecutionService();
    final result = await exec.run(
      sanitizedCommand,
      sanitizedParams,
      workingDirectory: workingDirectory,
      runInShell: runInShell,
      onOutput: onOutput,
    );

    manager.audit(
      SecurityEvent(
        moduleId: 'CommandExecutor',
        securityEventType: 'command_execution_completed',
        severity: result.exitCode == 0 ? 'info' : 'warning',
        resource: sanitizedCommand,
        details: {
          'parameters': sanitizedParams,
          'exitCode': result.exitCode,
          'name': command.name,
        },
      ),
    );

    if (checkExitCode && result.exitCode != 0) {
      final err = result.stderr.toString().trim();
      throw Exception('Command failed: $err');
    }

    return result;
  }

}
