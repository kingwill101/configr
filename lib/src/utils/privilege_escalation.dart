import 'dart:async';
import 'dart:io';
import 'package:configr/src/utils/execution_service.dart';
import 'package:configr/src/utils/logging.dart';

/// Session-based privilege lock for maintaining elevated privileges
/// across multiple operations.
///
/// Unlike the old singleton [PrivilegeLock], this is an instance-based lock
/// with a configurable timeout.  Create a new instance per session or
/// per [ConfigrConfig].
class PrivilegeLock {
  /// Configurable timeout — defaults to 15 minutes.
  final Duration timeout;

  bool _isActive = false;
  DateTime? _lastUsed;
  Timer? _timeoutTimer;

  PrivilegeLock({this.timeout = const Duration(minutes: 15)});

  bool get isActive => _isActive;
  DateTime? get lastUsed => _lastUsed;

  Duration? get timeUntilTimeout {
    if (!_isActive || _lastUsed == null) return null;
    final elapsed = DateTime.now().difference(_lastUsed!);
    return timeout - elapsed;
  }

  /// Acquire privilege lock.
  void acquire() {
    if (_isActive) {
      _updateLastUsed();
      return;
    }

    _isActive = true;
    _lastUsed = DateTime.now();
    _startTimeoutTimer();
    logger.info('Privilege lock acquired (timeout: ${timeout.inMinutes} min)');
  }

  /// Release privilege lock.
  void release() {
    if (!_isActive) return;

    _isActive = false;
    _lastUsed = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    logger.info('Privilege lock released');
  }

  /// Update last used timestamp and reset timeout.
  void _updateLastUsed() {
    _lastUsed = DateTime.now();
    _timeoutTimer?.cancel();
    _startTimeoutTimer();
  }

  /// Start timeout timer.
  void _startTimeoutTimer() {
    _timeoutTimer = Timer(timeout, () {
      logger.info(
        'Privilege lock timed out after ${timeout.inMinutes} minutes',
      );
      release();
    });
  }

  /// Force release privilege lock (for cleanup).
  void forceRelease() {
    _isActive = false;
    _lastUsed = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    logger.warning('Privilege lock force released');
  }
}

abstract class PrivilegeEscalation {
  Future<ProcessResult> runWithElevatedPrivileges(
    String command,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
  });

  /// Check if privilege lock should be used
  bool get usePrivilegeLock => false;
}

class InteractiveSudoEscalation implements PrivilegeEscalation {
  final ExecutionService executionService;
  final bool keepPrivilegeLock;
  final PrivilegeLock? privilegeLock;

  InteractiveSudoEscalation({
    this.executionService = const LocalExecutionService(),
    this.keepPrivilegeLock = false,
    this.privilegeLock,
  });

  @override
  bool get usePrivilegeLock => keepPrivilegeLock;

  @override
  Future<ProcessResult> runWithElevatedPrivileges(
    String command,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
  }) async {
    if (usePrivilegeLock && privilegeLock != null && privilegeLock!.isActive) {
      try {
        var result = await executionService.run('sudo', [
          '-n',
          command,
          ...arguments,
        ], workingDirectory: workingDirectory);
        if (result.exitCode == 0) {
          privilegeLock!._updateLastUsed();
          return result;
        }
      } catch (e) {
        logger.warning(
          'Failed to use privilege lock, falling back to authentication: $e',
        );
      }
    }

    var result = await executionService.run('sudo', [
      '-n',
      command,
      ...arguments,
    ], workingDirectory: workingDirectory);
    if (result.exitCode == 0) {
      if (usePrivilegeLock && privilegeLock != null) {
        privilegeLock!.acquire();
      }
      return result;
    }

    try {
      stderr.writeln(
        'Sudo password required to run: $command ${arguments.join(' ')}',
      );
      stderr.write('Password: ');
      stdin.echoMode = false;
      final password = stdin.readLineSync() ?? '';
      stdin.echoMode = true;
      stderr.writeln('');

      if (password.isEmpty) {
        throw Exception('Password required but not provided');
      }

      final fullCommand =
          'echo "$password" | sudo -S $command ${arguments.join(' ')}';
      result = await executionService.run('sh', [
        '-c',
        fullCommand,
      ], workingDirectory: workingDirectory);

      if (result.exitCode != 0) {
        throw Exception('Failed to run command with sudo: ${result.stderr}');
      }

      if (usePrivilegeLock && privilegeLock != null) {
        privilegeLock!.acquire();
      }

      return result;
    } catch (e) {
      throw Exception('Failed to get password for sudo: $e');
    }
  }
}

class NonInteractiveSudoEscalation implements PrivilegeEscalation {
  final ExecutionService executionService;
  final bool keepPrivilegeLock;
  final PrivilegeLock? privilegeLock;

  NonInteractiveSudoEscalation({
    this.executionService = const LocalExecutionService(),
    this.keepPrivilegeLock = false,
    this.privilegeLock,
  });

  @override
  bool get usePrivilegeLock => keepPrivilegeLock;

  @override
  Future<ProcessResult> runWithElevatedPrivileges(
    String command,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
  }) async {
    if (usePrivilegeLock && privilegeLock != null && privilegeLock!.isActive) {
      try {
        var result = await executionService.run('sudo', [
          '-n',
          command,
          ...arguments,
        ], workingDirectory: workingDirectory);
        if (result.exitCode == 0) {
          privilegeLock!._updateLastUsed();
          return result;
        }
      } catch (e) {
        logger.warning(
          'Failed to use privilege lock, falling back to passwordless sudo: $e',
        );
      }
    }

    var result = await executionService.run('sudo', [
      '-n',
      command,
      ...arguments,
    ], workingDirectory: workingDirectory);

    if (result.exitCode == 0) {
      if (usePrivilegeLock && privilegeLock != null) {
        privilegeLock!.acquire();
      }
      return result;
    }

    final stderrStr = result.stderr is String
        ? result.stderr as String
        : String.fromCharCodes(result.stderr as List<int>);
    if (stderrStr.contains('sudo:') || stderrStr.contains('sorry')) {
      throw Exception(
        'Passwordless sudo required but not available. '
        'Please configure passwordless sudo or run with appropriate privileges.',
      );
    }

    return result;
  }
}

class NoPrivilegeEscalation implements PrivilegeEscalation {
  final ExecutionService executionService;

  const NoPrivilegeEscalation({
    this.executionService = const LocalExecutionService(),
  });

  @override
  bool get usePrivilegeLock => false;

  @override
  Future<ProcessResult> runWithElevatedPrivileges(
    String command,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
  }) async {
    return executionService.run(
      command,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: runInShell,
    );
  }
}
