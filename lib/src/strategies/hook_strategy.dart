import 'package:configr/src/utils/shell_type.dart';

/// Platform-specific hook execution strategy.
///
/// Determines the correct shell and invocation for running hook scripts
/// based on the target platform.
abstract class HookStrategy {
  const HookStrategy();

  /// Create the appropriate strategy for [platform].
  factory HookStrategy.forPlatform(String platform) {
    final lower = platform.toLowerCase();
    if (lower.contains('windows')) {
      return const WindowsHookStrategy();
    }
    return const UnixHookStrategy();
  }

  /// Executable and args to run a hook script at [scriptPath].
  (String, List<String>) runScript(String scriptPath);

  /// Executable and args for the default interactive shell.
  (String, List<String>) interactiveShell(String script);

  /// Executable and args to allocate a unique temp file path on the remote host.
  (String, List<String>) tempFilePath(String suffix);

  /// Executable and args to remove a file on the remote host.
  (String, List<String>) removeFile(String filePath);
}

/// Unix implementation — uses bash for hooks, sh for interactive commands.
class UnixHookStrategy extends HookStrategy {
  const UnixHookStrategy();

  @override
  (String, List<String>) runScript(String scriptPath) {
    return (ShellType.bash.defaultExecutable, [scriptPath]);
  }

  @override
  (String, List<String>) interactiveShell(String script) {
    return (ShellType.sh.defaultExecutable, ShellType.sh.scriptArgs(script));
  }

  @override
  (String, List<String>) tempFilePath(String suffix) {
    return (
      ShellType.sh.defaultExecutable,
      ShellType.sh.scriptArgs(
        r'tmpdir="${TMPDIR:-/tmp}" && mkdir -p "$tmpdir" && '
        'mktemp "\$tmpdir/configr_hook_XXXXXX_$suffix"',
      ),
    );
  }

  @override
  (String, List<String>) removeFile(String filePath) {
    return (
      ShellType.sh.defaultExecutable,
      ['-c', 'rm -f "\$@"', 'sh', filePath],
    );
  }
}

/// Windows implementation — uses PowerShell for hooks.
class WindowsHookStrategy extends HookStrategy {
  const WindowsHookStrategy();

  @override
  (String, List<String>) runScript(String scriptPath) {
    // Use -EncodedCommand to invoke the script. This avoids cmd.exe quoting
    // issues with -File (whose path argument receives POSIX '...' wrapping
    // from _escapeArg that cmd.exe doesn't understand).
    final safePath = scriptPath.replaceAll("'", "''");
    final invoke = "& '$safePath'";
    return (
      ShellType.powershell.defaultExecutable,
      ShellType.powershell.scriptArgs(invoke),
    );
  }

  @override
  (String, List<String>) interactiveShell(String script) {
    return (
      ShellType.powershell.defaultExecutable,
      ShellType.powershell.scriptArgs(script),
    );
  }

  @override
  (String, List<String>) tempFilePath(String suffix) {
    final normalizedSuffix = suffix.startsWith('.') ? suffix : '_$suffix';
    final safeSuffix = normalizedSuffix.replaceAll("'", "''");
    final script =
        "Write-Output ([System.IO.Path]::Combine("
        "[System.IO.Path]::GetTempPath(), "
        "'configr_hook_' + [System.IO.Path]::GetRandomFileName() + '"
        "$safeSuffix'))";
    return (
      ShellType.powershell.defaultExecutable,
      ShellType.powershell.scriptArgs(script),
    );
  }

  @override
  (String, List<String>) removeFile(String filePath) {
    final safePath = filePath.replaceAll("'", "''");
    final script = "Remove-Item -Force '$safePath'";
    return (
      ShellType.powershell.defaultExecutable,
      ShellType.powershell.scriptArgs(script),
    );
  }
}
