import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/models/command.dart';
import 'package:configr/src/security/input_sanitizer.dart';
import 'package:configr/src/security/security_manager.dart';
import 'package:configr/src/utils/privilege_escalation.dart';

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

    ProcessResult result;
    if (onOutput != null) {
      result = await _runStreaming(
        sanitizedCommand,
        sanitizedParams,
        onOutput,
        workingDirectory: workingDirectory,
        runInShell: runInShell,
      );
    } else {
      result = await _runStreaming(
        sanitizedCommand,
        sanitizedParams,
        null,
        workingDirectory: workingDirectory,
        runInShell: runInShell,
      );
    }

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

  static Future<ProcessResult> _runStreaming(
    String command,
    List<String> arguments,
    CommandOutputHandler? onOutput, {
    String? workingDirectory,
    bool runInShell = false,
  }) async {
    final process = await Process.start(
      command,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: runInShell,
    );

    final stdoutBuf = StringBuffer();
    final stderrBuf = StringBuffer();

    final stdoutDone = onOutput != null
        ? process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .forEach((line) {
            stdoutBuf.writeln(line);
            onOutput(line, false);
          })
        : process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .forEach((line) => stdoutBuf.writeln(line));

    final stderrDone = onOutput != null
        ? process.stderr
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .forEach((line) {
            stderrBuf.writeln(line);
            onOutput(line, true);
          })
        : process.stderr
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .forEach((line) => stderrBuf.writeln(line));

    await Future.wait([stdoutDone, stderrDone]);
    final exitCode = await process.exitCode;

    return ProcessResult(
      process.pid,
      exitCode,
      stdoutBuf.toString(),
      stderrBuf.toString(),
    );
  }
}
