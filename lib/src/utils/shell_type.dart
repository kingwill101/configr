import 'dart:convert';
import 'dart:typed_data';

import 'package:configr/src/utils/platform.dart' show OperatingSystem;

/// Shell types supported for command execution.
///
/// Each variant knows its default executable path and how to build a `-c`
/// style argument list for running a command string.
enum ShellType {
  /// POSIX sh — available on Unix-likes and via Git Bash on Windows.
  sh(defaultExecutable: '/bin/sh'),

  /// Bash — common on Linux/macOS, available via Git Bash/WSL on Windows.
  bash(defaultExecutable: '/bin/bash'),

  /// PowerShell — native on Windows, cross-platform via `pwsh`.
  powershell(defaultExecutable: 'powershell'),

  /// Windows Command Prompt — native on Windows.
  cmd(defaultExecutable: 'cmd');

  /// Default executable path for this shell type.
  final String defaultExecutable;

  const ShellType({required this.defaultExecutable});

  /// Build argument list for running [command] through this shell's `-c`
  /// equivalent.
  List<String> scriptArgs(String command) {
    return switch (this) {
      ShellType.sh || ShellType.bash => ['-c', command],
      ShellType.powershell => powershellEncodedCommand(command),
      ShellType.cmd => ['/c', command],
    };
  }

  /// Whether this shell is typically available on [os].
  ///
  /// Returns `true` for the target's platform shell and `false` for shells
  /// that are uncommon (but still possible) on that OS.
  bool isAvailableOn(OperatingSystem os) {
    return switch (this) {
      ShellType.sh => os != OperatingSystem.windows,
      ShellType.bash => os != OperatingSystem.windows,
      ShellType.powershell => true,
      ShellType.cmd => os == OperatingSystem.windows,
    };
  }

  /// Resolve the executable path for this shell on [os].
  ///
  /// On Unix-likes returns the default POSIX path. On Windows, PowerShell
  /// uses the short `powershell` name (resolved via PATH).
  String executableFor(OperatingSystem os) {
    return switch (this) {
      ShellType.sh || ShellType.bash => defaultExecutable,
      ShellType.powershell =>
        os == OperatingSystem.windows ? 'powershell' : 'pwsh',
      ShellType.cmd => 'cmd',
    };
  }

  /// Parse a [value] (e.g. from config) into a [ShellType].
  ///
  /// Accepts `"sh"`, `"bash"`, `"powershell"` (case-insensitive).
  /// Returns `null` for unrecognised values.
  static ShellType? tryParse(String value) {
    return switch (value.toLowerCase()) {
      'sh' || '/bin/sh' => ShellType.sh,
      'bash' || '/bin/bash' => ShellType.bash,
      'powershell' ||
      'pwsh' ||
      'pwsh.exe' ||
      'powershell.exe' => ShellType.powershell,
      'cmd' || 'cmd.exe' => ShellType.cmd,
      _ => null,
    };
  }

  /// Build a PowerShell `-EncodedCommand` argument list.
  ///
  /// PowerShell expects UTF-16LE before base64 encoding. Using an encoded
  /// command keeps SSH exec invocations from being broken by nested quoting,
  /// Windows paths, semicolons, and pipe characters in user scripts.
  static List<String> powershellEncodedCommand(String command) {
    final units = command.codeUnits;
    final bytes = Uint8List(units.length * 2);
    for (var i = 0; i < units.length; i++) {
      bytes[i * 2] = units[i] & 0xFF;
      bytes[i * 2 + 1] = (units[i] >> 8) & 0xFF;
    }
    return ['-NoProfile', '-EncodedCommand', base64Encode(bytes)];
  }

  /// Build arguments for PowerShell scripts supplied over stdin.
  static List<String> powershellStdinCommand() => const [
    '-NoProfile',
    '-Command',
    '-',
  ];
}
