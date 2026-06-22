import 'dart:async';
import 'dart:io';
import 'package:configr/src/cli/ui/handlers/base_handler.dart';
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
    List<String> arguments,
  );

  /// Check if privilege lock should be used
  bool get usePrivilegeLock => false;
}

class InteractiveSudoEscalation implements PrivilegeEscalation {
  final UIHandler? uiHandler;
  final bool keepPrivilegeLock;
  final PrivilegeLock? privilegeLock;

  InteractiveSudoEscalation({
    this.uiHandler,
    this.keepPrivilegeLock = false,
    this.privilegeLock,
  });

  @override
  bool get usePrivilegeLock => keepPrivilegeLock;

  @override
  Future<ProcessResult> runWithElevatedPrivileges(
    String command,
    List<String> arguments,
  ) async {
    // If privilege lock is enabled and active, try to use it first
    if (usePrivilegeLock && privilegeLock != null && privilegeLock!.isActive) {
      try {
        var result = await Process.run('sudo', ['-n', command, ...arguments]);
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

    // First, try running sudo with -n (non-interactive) to see if we have passwordless sudo
    var result = await Process.run('sudo', ['-n', command, ...arguments]);
    if (result.exitCode == 0) {
      if (usePrivilegeLock && privilegeLock != null) {
        privilegeLock!.acquire();
      }
      return result;
    }

    // If passwordless sudo is not available, try using the UI handler for password input
    if (uiHandler != null) {
      uiHandler!.enablePasswordPromptMode();

      try {
        final password = uiHandler!.promptPassword(
          'Sudo password required to run: $command ${arguments.join(' ')}',
        );

        if (password.isEmpty) {
          throw Exception('Password required but not provided');
        }

        // Use a shell to echo the password into sudo
        final fullCommand =
            'echo "$password" | sudo -S $command ${arguments.join(' ')}';
        result = await Process.run('sh', ['-c', fullCommand]);

        if (result.exitCode != 0) {
          throw Exception('Failed to run command with sudo: ${result.stderr}');
        }

        // Acquire privilege lock after successful authentication
        if (usePrivilegeLock && privilegeLock != null) {
          privilegeLock!.acquire();
        }

        return result;
      } finally {
        uiHandler!.disablePasswordPromptMode();
      }
    } else {
      // Fallback to direct stdin if no UI handler is available
      try {
        stderr.writeln(
          'Sudo password required to run: $command ${arguments.join(' ')}',
        );
        stderr.write('Password: ');
        stdin.echoMode = false;
        final password = stdin.readLineSync() ?? '';
        stdin.echoMode = true;
        stderr.writeln(''); // New line after password input

        if (password.isEmpty) {
          throw Exception('Password required but not provided');
        }

        // Use a shell to echo the password into sudo
        final fullCommand =
            'echo "$password" | sudo -S $command ${arguments.join(' ')}';
        result = await Process.run('sh', ['-c', fullCommand]);

        if (result.exitCode != 0) {
          throw Exception('Failed to run command with sudo: ${result.stderr}');
        }

        // Acquire privilege lock after successful authentication
        if (usePrivilegeLock && privilegeLock != null) {
          privilegeLock!.acquire();
        }

        return result;
      } catch (e) {
        throw Exception('Failed to get password for sudo: $e');
      }
    }
  }
}

class NonInteractiveSudoEscalation implements PrivilegeEscalation {
  final bool keepPrivilegeLock;
  final PrivilegeLock? privilegeLock;

  NonInteractiveSudoEscalation({
    this.keepPrivilegeLock = false,
    this.privilegeLock,
  });

  @override
  bool get usePrivilegeLock => keepPrivilegeLock;

  @override
  Future<ProcessResult> runWithElevatedPrivileges(
    String command,
    List<String> arguments,
  ) async {
    // If privilege lock is enabled and active, try to use it first
    if (usePrivilegeLock && privilegeLock != null && privilegeLock!.isActive) {
      try {
        var result = await Process.run('sudo', ['-n', command, ...arguments]);
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

    // Try running sudo with -n (non-interactive) to see if we have passwordless sudo
    var result = await Process.run('sudo', ['-n', command, ...arguments]);
    if (result.exitCode == 0) {
      if (usePrivilegeLock && privilegeLock != null) {
        privilegeLock!.acquire();
      }
      return result;
    }

    // If passwordless sudo is not available, throw an error instead of prompting
    throw Exception(
      'Passwordless sudo required but not available. Please configure passwordless sudo or run with appropriate privileges.',
    );
  }
}

class NoPrivilegeEscalation implements PrivilegeEscalation {
  @override
  bool get usePrivilegeLock => false;

  @override
  Future<ProcessResult> runWithElevatedPrivileges(
    String command,
    List<String> arguments,
  ) async {
    // Run command directly without any privilege escalation
    return await Process.run(command, arguments);
  }
}
