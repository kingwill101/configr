import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef CommandOutputHandler = void Function(String line, bool isStderr);

abstract class ExecutionService {
  /// Target platform identifier, e.g. `linux`, `macos`, `windows`.
  String get platform;

  Future<ProcessResult> run(
    String command,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
    Map<String, String>? environment,
    CommandOutputHandler? onOutput,
    String? stdin,
  });

  Future<void> connect(Map<String, dynamic> config);
  Future<void> disconnect();
  bool get isConnected;
  Future<void> putFile(String sourcePath, String destinationPath);
  Future<void> fetchFile(String sourcePath, String destinationPath);
}

class LocalExecutionService implements ExecutionService {
  const LocalExecutionService();

  @override
  String get platform => Platform.operatingSystem;

  @override
  bool get isConnected => true;

  @override
  Future<void> connect(Map<String, dynamic> config) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> putFile(String sourcePath, String destinationPath) async {
    await File(sourcePath).copy(destinationPath);
  }

  @override
  Future<void> fetchFile(String sourcePath, String destinationPath) async {
    await File(sourcePath).copy(destinationPath);
  }

  @override
  Future<ProcessResult> run(
    String command,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
    Map<String, String>? environment,
    CommandOutputHandler? onOutput,
    String? stdin,
  }) async {
    if (stdin != null ||
        onOutput != null ||
        (environment != null && environment.isNotEmpty)) {
      return _runStreaming(
        command,
        arguments,
        onOutput,
        workingDirectory: workingDirectory,
        runInShell: runInShell,
        environment: environment,
        stdin: stdin,
      );
    }
    return Process.run(
      command,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: runInShell,
    );
  }

  Future<ProcessResult> _runStreaming(
    String command,
    List<String> arguments,
    CommandOutputHandler? onOutput, {
    String? workingDirectory,
    bool runInShell = false,
    Map<String, String>? environment,
    String? stdin,
  }) async {
    final process = await Process.start(
      command,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: runInShell,
      environment: environment,
    );

    if (stdin != null) {
      process.stdin.write(stdin);
      await process.stdin.close();
    }

    final stdoutBuf = StringBuffer();
    final stderrBuf = StringBuffer();

    final stdoutDone = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) {
          stdoutBuf.writeln(line);
          onOutput?.call(line, false);
        });

    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) {
          stderrBuf.writeln(line);
          onOutput?.call(line, true);
        });

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
