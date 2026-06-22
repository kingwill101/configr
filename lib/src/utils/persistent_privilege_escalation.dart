import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:configr/src/utils/logging.dart';
import 'package:configr/src/utils/privilege_escalation.dart';

/// Enhanced privilege lock that maintains a persistent shell session
class PersistentPrivilegeLock {
  static PersistentPrivilegeLock? _instance;
  static PersistentPrivilegeLock get instance =>
      _instance ??= PersistentPrivilegeLock._();

  PersistentPrivilegeLock._();

  bool _isActive = false;
  DateTime? _lastUsed;
  Timer? _timeoutTimer;
  Process? _shellProcess;
  StreamController<String>? _inputController;
  StreamController<String>? _outputController;
  StreamController<String>? _errorController;
  static const Duration _timeoutDuration = Duration(minutes: 15);

  bool get isActive => _isActive && _shellProcess != null;
  DateTime? get lastUsed => _lastUsed;
  Duration? get timeUntilTimeout {
    if (!_isActive || _lastUsed == null) return null;
    final elapsed = DateTime.now().difference(_lastUsed!);
    return _timeoutDuration - elapsed;
  }

  /// Acquire privilege lock with persistent shell
  Future<void> acquire({dynamic uiHandler}) async {
    if (_isActive && _shellProcess != null) {
      _updateLastUsed();
      return;
    }

    // Start a persistent sudo shell
    await _startPersistentShell(uiHandler: uiHandler);

    _isActive = true;
    _lastUsed = DateTime.now();
    _startTimeoutTimer();
    logger.info(
      'Persistent privilege lock acquired with shell PID: ${_shellProcess?.pid}',
    );
  }

  /// Release privilege lock and terminate shell
  void release() {
    if (!_isActive) return;

    _isActive = false;
    _lastUsed = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;

    // Terminate the persistent shell
    _shellProcess?.kill();
    _shellProcess = null;
    _inputController?.close();
    _outputController?.close();
    _errorController?.close();
    _inputController = null;
    _outputController = null;
    _errorController = null;

    logger.info('Persistent privilege lock released');
  }

  /// Execute a command in the persistent shell
  Future<ProcessResult> executeCommand(
    String command,
    List<String> arguments,
  ) async {
    if (!isActive) {
      throw Exception('Privilege lock is not active');
    }

    final fullCommand = '$command ${arguments.join(' ')}';
    final commandId = DateTime.now().millisecondsSinceEpoch.toString();

    // Send command to shell with unique identifier
    final commandWithId =
        'echo "CMD_START:$commandId" && $fullCommand && echo "CMD_END:$commandId"';
    _inputController?.add('$commandWithId\n');

    // Wait for command completion
    final result = await _waitForCommandCompletion(commandId);

    _updateLastUsed();
    return result;
  }

  /// Start a persistent sudo shell
  Future<void> _startPersistentShell({dynamic uiHandler}) async {
    try {
      // First, try to get sudo access
      final authResult = await _authenticateSudo(uiHandler: uiHandler);
      if (!authResult) {
        throw Exception('Failed to authenticate with sudo');
      }

      // Start persistent shell
      _shellProcess = await Process.start('sudo', [
        '-i',
      ], mode: ProcessStartMode.normal);

      // Create stream controllers for communication
      _inputController = StreamController<String>();
      _outputController = StreamController<String>();
      _errorController = StreamController<String>();

      // Set up input stream
      _inputController!.stream.listen((input) {
        _shellProcess!.stdin.writeln(input);
      });

      // Set up output streams
      _shellProcess!.stdout.transform(utf8.decoder).listen((output) {
        _outputController!.add(output);
      });

      _shellProcess!.stderr.transform(utf8.decoder).listen((error) {
        _errorController!.add(error);
      });

      // Wait for shell to be ready
      await Future.delayed(Duration(milliseconds: 500));

      // Test the shell
      _inputController!.add('echo "SHELL_READY"');
      await Future.delayed(Duration(milliseconds: 200));

      logger.info('Persistent sudo shell started successfully');
    } catch (e) {
      logger.severe('Failed to start persistent shell: $e');
      _cleanup();
      rethrow;
    }
  }

  /// Authenticate with sudo
  Future<bool> _authenticateSudo({dynamic uiHandler}) async {
    // Try passwordless sudo first
    var result = await Process.run('sudo', ['-n', 'echo', 'AUTH_SUCCESS']);
    if (result.exitCode == 0) {
      return true;
    }

    // If passwordless sudo is not available, prompt for password
    if (uiHandler != null) {
      uiHandler.enablePasswordPromptMode();

      try {
        final password = uiHandler.promptPassword(
          'Sudo password required for persistent privilege lock',
        );

        if (password.isEmpty) {
          return false;
        }

        // Test authentication
        final fullCommand = 'echo "$password" | sudo -S echo "AUTH_SUCCESS"';
        result = await Process.run('sh', ['-c', fullCommand]);

        return result.exitCode == 0;
      } finally {
        uiHandler.disablePasswordPromptMode();
      }
    } else {
      // Fallback to direct stdin
      try {
        stderr.writeln('Sudo password required for persistent privilege lock');
        stderr.write('Password: ');
        stdin.echoMode = false;
        final password = stdin.readLineSync() ?? '';
        stdin.echoMode = true;
        stderr.writeln('');

        if (password.isEmpty) {
          return false;
        }

        final fullCommand = 'echo "$password" | sudo -S echo "AUTH_SUCCESS"';
        result = await Process.run('sh', ['-c', fullCommand]);

        return result.exitCode == 0;
      } catch (e) {
        return false;
      }
    }
  }

  /// Wait for command completion in the shell
  Future<ProcessResult> _waitForCommandCompletion(String commandId) async {
    final outputBuffer = StringBuffer();
    final errorBuffer = StringBuffer();
    bool commandStarted = false;
    bool commandEnded = false;

    // Listen for output until command completes
    final subscription = _outputController!.stream.listen((output) {
      if (!commandStarted && output.contains('CMD_START:$commandId')) {
        commandStarted = true;
        return;
      }

      if (commandStarted && !commandEnded) {
        if (output.contains('CMD_END:$commandId')) {
          commandEnded = true;
          return;
        }
        outputBuffer.write(output);
      }
    });

    // Wait for command to complete or timeout
    final timeout = Duration(seconds: 30);
    final startTime = DateTime.now();

    while (!commandEnded && DateTime.now().difference(startTime) < timeout) {
      await Future.delayed(Duration(milliseconds: 100));
    }

    await subscription.cancel();

    if (!commandEnded) {
      throw Exception('Command timed out after ${timeout.inSeconds} seconds');
    }

    return ProcessResult(
      _shellProcess!.pid,
      0, // Exit code (we assume success if we got here)
      outputBuffer.toString(),
      errorBuffer.toString(),
    );
  }

  /// Update last used timestamp and reset timeout
  void _updateLastUsed() {
    _lastUsed = DateTime.now();
    _timeoutTimer?.cancel();
    _startTimeoutTimer();
  }

  /// Start timeout timer
  void _startTimeoutTimer() {
    _timeoutTimer = Timer(_timeoutDuration, () {
      logger.info(
        'Persistent privilege lock timed out after ${_timeoutDuration.inMinutes} minutes',
      );
      release();
    });
  }

  /// Cleanup resources
  void _cleanup() {
    _shellProcess?.kill();
    _shellProcess = null;
    _inputController?.close();
    _outputController?.close();
    _errorController?.close();
    _inputController = null;
    _outputController = null;
    _errorController = null;
  }

  /// Force release privilege lock (for cleanup)
  void forceRelease() {
    _isActive = false;
    _lastUsed = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _cleanup();
    logger.warning('Persistent privilege lock force released');
  }

  /// Reset singleton instance (for testing)
  static void reset() {
    _instance?.forceRelease();
    _instance = null;
  }
}

/// Enhanced privilege escalation that uses persistent shell
class PersistentSudoEscalation implements PrivilegeEscalation {
  final dynamic uiHandler;
  final bool keepPrivilegeLock;

  PersistentSudoEscalation({this.uiHandler, this.keepPrivilegeLock = false});

  @override
  bool get usePrivilegeLock => keepPrivilegeLock;

  @override
  Future<ProcessResult> runWithElevatedPrivileges(
    String command,
    List<String> arguments,
  ) async {
    final lock = PersistentPrivilegeLock.instance;

    // If privilege lock is enabled and active, use the persistent shell
    if (usePrivilegeLock && lock.isActive) {
      try {
        return await lock.executeCommand(command, arguments);
      } catch (e) {
        logger.warning(
          'Failed to use persistent privilege lock, falling back to direct sudo: $e',
        );
        // Fall through to direct sudo
      }
    }

    // If privilege lock is enabled but not active, try to acquire it
    if (usePrivilegeLock && !lock.isActive) {
      try {
        await lock.acquire(uiHandler: uiHandler);
        return await lock.executeCommand(command, arguments);
      } catch (e) {
        logger.warning(
          'Failed to acquire persistent privilege lock, falling back to direct sudo: $e',
        );
        // Fall through to direct sudo
      }
    }

    // Fallback to direct sudo (original behavior)
    return await _runDirectSudo(command, arguments);
  }

  /// Fallback to direct sudo execution
  Future<ProcessResult> _runDirectSudo(
    String command,
    List<String> arguments,
  ) async {
    // Try passwordless sudo first
    var result = await Process.run('sudo', ['-n', command, ...arguments]);
    if (result.exitCode == 0) {
      return result;
    }

    // If passwordless sudo is not available, prompt for password
    if (uiHandler != null) {
      uiHandler!.enablePasswordPromptMode();

      try {
        final password = uiHandler!.promptPassword(
          'Sudo password required to run: $command ${arguments.join(' ')}',
        );

        if (password.isEmpty) {
          throw Exception('Password required but not provided');
        }

        final fullCommand =
            'echo "$password" | sudo -S $command ${arguments.join(' ')}';
        result = await Process.run('sh', ['-c', fullCommand]);

        if (result.exitCode != 0) {
          throw Exception('Failed to run command with sudo: ${result.stderr}');
        }

        return result;
      } finally {
        uiHandler!.disablePasswordPromptMode();
      }
    } else {
      // Fallback to direct stdin
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
        result = await Process.run('sh', ['-c', fullCommand]);

        if (result.exitCode != 0) {
          throw Exception('Failed to run command with sudo: ${result.stderr}');
        }

        return result;
      } catch (e) {
        throw Exception('Failed to get password for sudo: $e');
      }
    }
  }
}
