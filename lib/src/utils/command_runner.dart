import 'dart:io';

import 'package:configr/src/di.dart';
import 'package:configr/src/models/command.dart';
import 'package:configr/src/utils/command_executor.dart';
import 'package:configr/src/utils/execution_service.dart';
import 'package:configr/src/utils/privilege_escalation.dart'
    show PrivilegeEscalation;

/// Injectable command runner that abstracts execution of system commands.
///
/// All implementations route through [CommandExecutor] so that security
/// checks (input sanitization, security manager validation, audit events)
/// are always applied. Blocks should depend on this interface instead of
/// calling [CommandExecutor] or [Process.run] directly.
abstract class CommandRunner {
  /// Run [command] with [arguments] and return the result.
  ///
  /// Delegates to [CommandExecutor.execute] for the actual execution.
  /// [environment] is passed directly to [Process.run] when set (the
  /// executor does not support custom env vars).
  Future<ProcessResult> run(
    String command,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool runInShell = false,
  });

  /// Run a command and capture stdout as a trimmed string.
  /// Throws if the exit code is non-zero.
  Future<String> runAndCapture(
    String command,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool runInShell = false,
  });

  /// Check whether a command/program is available on the system.
  Future<bool> commandExists(String command);
}

/// Concrete [CommandRunner] that delegates to [CommandExecutor] for security-
/// checked local command execution.
///
/// Resolves [PrivilegeEscalation] from the DI container so the same escalation
/// strategy (e.g. sudo, non-interactive) is used everywhere.
class LocalCommandRunner implements CommandRunner {
  const LocalCommandRunner();
  PrivilegeEscalation get _privilegeEscalation => di<PrivilegeEscalation>();
  ExecutionService get _executionService => di.isRegistered<ExecutionService>()
      ? di<ExecutionService>()
      : const LocalExecutionService();

  @override
  Future<ProcessResult> run(
    String command,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool runInShell = false,
  }) async {
    if (environment != null && environment.isNotEmpty) {
      return _executionService.run(
        command,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
        runInShell: runInShell,
      );
    }

    final cmd = Command(name: command, command: command, parameters: arguments);
    return CommandExecutor.execute(
      cmd,
      _privilegeEscalation,
      workingDirectory: workingDirectory,
      runInShell: runInShell,
      executionService: _executionService,
    );
  }

  @override
  Future<String> runAndCapture(
    String command,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool runInShell = false,
  }) async {
    final result = await run(
      command,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: runInShell,
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        command,
        arguments,
        result.stderr?.toString() ?? '',
        result.exitCode,
      );
    }
    return (result.stdout as String).trim();
  }

  @override
  Future<bool> commandExists(String command) async {
    try {
      final result = await _executionService.run('which', [
        command,
      ], runInShell: true);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}

/// [CommandRunner] that logs every command before executing.
///
/// Useful for debugging or verbose-mode execution.
class LoggingCommandRunner implements CommandRunner {
  final CommandRunner _inner;
  final void Function(String message) log;

  const LoggingCommandRunner(this._inner, {required this.log});

  @override
  Future<ProcessResult> run(
    String command,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool runInShell = false,
  }) async {
    log('$command ${arguments.join(' ')}');
    return _inner.run(
      command,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: runInShell,
    );
  }

  @override
  Future<String> runAndCapture(
    String command,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool runInShell = false,
  }) async {
    log('$command ${arguments.join(' ')}');
    return _inner.runAndCapture(
      command,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: runInShell,
    );
  }

  @override
  Future<bool> commandExists(String command) async {
    return _inner.commandExists(command);
  }
}
