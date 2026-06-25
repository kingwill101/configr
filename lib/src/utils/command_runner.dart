import 'dart:io';

/// Injectable command runner that abstracts execution of system commands.
///
/// Blocks that shell out to system tools should depend on this interface
/// instead of calling `Process.run` directly, so execution can be swapped
/// for dry-run mode, logging wrappers, or remote SSH execution.
abstract class CommandRunner {
  /// Run [command] with [arguments] and return the result.
  Future<ProcessResult> run(
    String command,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool runInShell = false,
  });

  /// Run a command and capture stdout as a trimmed string.
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

/// Concrete [CommandRunner] that delegates to [Process.run] on the local
/// machine.
class LocalCommandRunner implements CommandRunner {
  const LocalCommandRunner();

  @override
  Future<ProcessResult> run(
    String command,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool runInShell = false,
  }) async {
    return Process.run(
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
    final result = await Process.run(
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
      final result = await Process.run(
        'which',
        [command],
        runInShell: true,
      );
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
