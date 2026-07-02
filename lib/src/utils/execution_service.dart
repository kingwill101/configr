import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

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

class AuditedExecutionService implements ExecutionService {
  static final _random = Random.secure();
  static int _sequence = 0;

  final ExecutionService delegate;
  final String logDirectory;
  final String sessionId;
  Future<void> _writeTail = Future.value();

  AuditedExecutionService({
    required this.delegate,
    required this.logDirectory,
    String? sessionId,
  }) : sessionId = sessionId ?? _newSessionId();

  @override
  String get platform => delegate.platform;

  @override
  bool get isConnected => delegate.isConnected;

  @override
  Future<void> connect(Map<String, dynamic> config) => delegate.connect(config);

  @override
  Future<void> disconnect() => delegate.disconnect();

  @override
  Future<void> putFile(String sourcePath, String destinationPath) {
    return delegate.putFile(sourcePath, destinationPath);
  }

  @override
  Future<void> fetchFile(String sourcePath, String destinationPath) {
    return delegate.fetchFile(sourcePath, destinationPath);
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
    final commandId = _nextCommandId();
    final startedAt = DateTime.now();
    final stopwatch = Stopwatch()..start();
    final decodedPowerShell = _decodePowerShellEncodedCommand(
      command,
      arguments,
    );

    await _writeRecord({
      'event': 'shell_call',
      'sessionId': sessionId,
      'commandId': commandId,
      'timestamp': startedAt.toIso8601String(),
      'platform': platform,
      'command': command,
      'arguments': arguments,
      ?(decodedPowerShell == null ? null : 'decodedCommand'): decodedPowerShell,
      'workingDirectory': workingDirectory,
      'runInShell': runInShell,
      'environment': _redactEnvironment(environment),
      'stdin': stdin,
    });

    try {
      final result = await delegate.run(
        command,
        arguments,
        workingDirectory: workingDirectory,
        runInShell: runInShell,
        environment: environment,
        onOutput: onOutput,
        stdin: stdin,
      );
      stopwatch.stop();
      await _writeRecord({
        'event': 'shell_response',
        'sessionId': sessionId,
        'commandId': commandId,
        'timestamp': DateTime.now().toIso8601String(),
        'startedAt': startedAt.toIso8601String(),
        'durationMs': stopwatch.elapsedMilliseconds,
        'exitCode': result.exitCode,
        'stdout': result.stdout.toString(),
        'stderr': result.stderr.toString(),
      });
      return result;
    } catch (error, stackTrace) {
      stopwatch.stop();
      await _writeRecord({
        'event': 'shell_error',
        'sessionId': sessionId,
        'commandId': commandId,
        'timestamp': DateTime.now().toIso8601String(),
        'startedAt': startedAt.toIso8601String(),
        'durationMs': stopwatch.elapsedMilliseconds,
        'error': error.toString(),
        'stackTrace': stackTrace.toString(),
      });
      rethrow;
    }
  }

  Future<void> _writeRecord(Map<String, Object?> record) {
    _writeTail = _writeTail.then((_) async {
      final directory = Directory(logDirectory);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final file = File('$logDirectory/shell-$sessionId.jsonl');
      await file.writeAsString(
        '${jsonEncode(record)}\n',
        mode: FileMode.append,
      );
    });
    return _writeTail;
  }

  static String _nextCommandId() {
    final sequence = _sequence++;
    return '${DateTime.now().microsecondsSinceEpoch}-$sequence';
  }

  static String _newSessionId() {
    final randomPart = List<int>.generate(
      6,
      (_) => _random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${DateTime.now().toIso8601String().replaceAll(':', '-')}-$randomPart';
  }

  static Map<String, String>? _redactEnvironment(
    Map<String, String>? environment,
  ) {
    if (environment == null) return null;
    return {
      for (final entry in environment.entries)
        entry.key: _isSensitiveKey(entry.key) ? '<redacted>' : entry.value,
    };
  }

  static bool _isSensitiveKey(String key) {
    final lower = key.toLowerCase();
    return lower.contains('password') ||
        lower.contains('passwd') ||
        lower.contains('token') ||
        lower.contains('secret') ||
        lower.contains('private') ||
        lower.contains('key');
  }

  static String? _decodePowerShellEncodedCommand(
    String command,
    List<String> arguments,
  ) {
    final lowerCommand = command.toLowerCase();
    if (!lowerCommand.endsWith('powershell') &&
        !lowerCommand.endsWith('powershell.exe') &&
        !lowerCommand.endsWith('pwsh') &&
        !lowerCommand.endsWith('pwsh.exe')) {
      return null;
    }

    for (var i = 0; i < arguments.length - 1; i++) {
      final arg = arguments[i].toLowerCase();
      if (arg == '-encodedcommand' || arg == '-enc') {
        try {
          final bytes = base64.decode(arguments[i + 1]);
          final codeUnits = <int>[];
          for (var j = 0; j + 1 < bytes.length; j += 2) {
            codeUnits.add(bytes[j] | (bytes[j + 1] << 8));
          }
          return String.fromCharCodes(codeUnits);
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }
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
