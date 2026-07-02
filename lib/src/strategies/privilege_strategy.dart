import 'package:configr/src/utils/execution_service.dart';
import 'package:configr/src/utils/shell_type.dart';

/// Result of executing a privileged command.
class PrivilegeResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  const PrivilegeResult(this.exitCode, this.stdout, this.stderr);
}

/// Platform-specific privilege escalation strategy.
///
/// Generates the appropriate command for running a privileged operation
/// on the target platform.
abstract class PrivilegeStrategy {
  const PrivilegeStrategy();

  /// Create the appropriate strategy for [platform].
  factory PrivilegeStrategy.forPlatform(String platform) {
    final lower = platform.toLowerCase();
    if (lower.contains('windows')) {
      return const WindowsPrivilegeStrategy();
    }
    return const UnixPrivilegeStrategy();
  }

  /// Whether privilege escalation is supported on this platform.
  bool get isSupported;

  /// Run [command] with [arguments] using elevated privileges.
  ///
  /// [password] is the escalation password (sudo password, etc.).
  /// Returns [PrivilegeResult] with the command output.
  Future<PrivilegeResult> runWithPrivileges({
    required ExecutionService executionService,
    required String command,
    required List<String> arguments,
    required String password,
    String? workingDirectory,
  });

  /// Test whether the escalation password is valid.
  Future<bool> testPassword({
    required ExecutionService executionService,
    required String password,
  });
}

/// Unix implementation using sudo via sh.
class UnixPrivilegeStrategy extends PrivilegeStrategy {
  const UnixPrivilegeStrategy();

  @override
  bool get isSupported => true;

  @override
  Future<PrivilegeResult> runWithPrivileges({
    required ExecutionService executionService,
    required String command,
    required List<String> arguments,
    required String password,
    String? workingDirectory,
  }) async {
    final fullCommand =
        'echo "$password" | sudo -S $command ${arguments.join(' ')}';
    final result = await executionService.run(
      ShellType.sh.defaultExecutable,
      ShellType.sh.scriptArgs(fullCommand),
      workingDirectory: workingDirectory,
    );
    return PrivilegeResult(
      result.exitCode,
      result.stdout as String,
      result.stderr as String,
    );
  }

  @override
  Future<bool> testPassword({
    required ExecutionService executionService,
    required String password,
  }) async {
    final fullCommand = 'echo "$password" | sudo -S echo "AUTH_SUCCESS"';
    final result = await executionService.run(
      ShellType.sh.defaultExecutable,
      ShellType.sh.scriptArgs(fullCommand),
    );
    return result.exitCode == 0;
  }
}

/// Windows implementation.
///
/// Windows does not have a direct sudo equivalent.
/// This strategy throws [UnsupportedError] when used.
class WindowsPrivilegeStrategy extends PrivilegeStrategy {
  const WindowsPrivilegeStrategy();

  @override
  bool get isSupported => false;

  @override
  Future<PrivilegeResult> runWithPrivileges({
    required ExecutionService executionService,
    required String command,
    required List<String> arguments,
    required String password,
    String? workingDirectory,
  }) async {
    throw UnsupportedError(
      'Privilege escalation is not supported on Windows targets. '
      'Run configr from an elevated (Administrator) shell instead.',
    );
  }

  @override
  Future<bool> testPassword({
    required ExecutionService executionService,
    required String password,
  }) async {
    return false;
  }
}
