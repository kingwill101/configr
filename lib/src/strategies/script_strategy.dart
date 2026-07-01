import 'package:configr/src/utils/shell_type.dart';

/// Platform-specific script execution strategy.
///
/// Determines the correct shell and arguments for running user-provided
/// pre-apply / post-apply scripts on the target platform.
///
/// Unlike [HookStrategy], this is purely a command factory for *running
/// an inline command string through a shell* — the caller is responsible
/// for invoking the [ExecutionService].
abstract class ScriptStrategy {
  const ScriptStrategy();

  /// Create the appropriate strategy for [platform].
  factory ScriptStrategy.forPlatform(String platform) {
    final lower = platform.toLowerCase();
    if (lower.contains('windows')) {
      return const WindowsScriptStrategy();
    }
    return const UnixScriptStrategy();
  }

  /// Executable and args to run [script] as a shell command.
  (String, List<String>) runScript(String script);

  /// Whether the default shell can be considered POSIX-compatible.
  bool get isPosix;
}

/// Unix implementation — uses sh.
class UnixScriptStrategy extends ScriptStrategy {
  const UnixScriptStrategy();

  @override
  (String, List<String>) runScript(String script) {
    return (ShellType.sh.defaultExecutable, ShellType.sh.scriptArgs(script));
  }

  @override
  bool get isPosix => true;
}

/// Windows implementation — uses PowerShell.
class WindowsScriptStrategy extends ScriptStrategy {
  const WindowsScriptStrategy();

  @override
  (String, List<String>) runScript(String script) {
    return (
      ShellType.powershell.defaultExecutable,
      ShellType.powershell.scriptArgs(script),
    );
  }

  @override
  bool get isPosix => false;
}
