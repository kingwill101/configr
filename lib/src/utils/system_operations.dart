/// Composes OS-appropriate shell commands for system operations.
///
/// Different operating systems use different flags for common utilities
/// like `stat`, `chown`, and `chmod`.  This utility maps [platform] to
/// the right syntax so callers (e.g. [FileService]) can compose commands
/// without platform-specific branching.
class SystemOperations {
  final String platform;

  const SystemOperations(this.platform);

  bool get isLinux => platform == 'linux';
  bool get isMacOS => platform == 'macos' || platform == 'darwin';
  bool get isWindows => platform == 'windows';

  /// Command and args to read `owner` and `group` of [path].
  (String, List<String>) getOwnership(String path) {
    if (isMacOS) {
      return ('stat', ['-f', '%Su %Sg', path]);
    }
    return ('stat', ['-c', '%U %G', path]);
  }

  /// Command and args to read permission octal string (e.g. `644`) of [path].
  (String, List<String>) getPermissions(String path) {
    if (isMacOS) {
      return ('stat', ['-f', '%OLp', path]);
    }
    return ('stat', ['-c', '%a', path]);
  }

  /// Command and args for `chown`.
  (String, List<String>) chown(String ownership, String path) {
    return ('chown', [ownership, path]);
  }

  /// Command and args for `chmod`.
  (String, List<String>) chmod(String mode, String path) {
    return ('chmod', [mode, path]);
  }

  /// Command and args to read numeric UID of [path].
  (String, List<String>) uid(String path) {
    if (isMacOS) return ('stat', ['-f', '%u', path]);
    return ('stat', ['-c', '%u', path]);
  }

  /// Command and args to read numeric GID of [path].
  (String, List<String>) gid(String path) {
    if (isMacOS) return ('stat', ['-f', '%g', path]);
    return ('stat', ['-c', '%g', path]);
  }

  /// Command and args for `mkdir -p`.
  (String, List<String>) mkdirp(String path) {
    return ('mkdir', ['-p', path]);
  }

  /// Try to determine the remote platform by inspecting the result of `uname`.
  static String detectPlatformFromUname(String uname) {
    final lower = uname.trim().toLowerCase();
    if (lower.contains('linux')) return 'linux';
    if (lower.contains('darwin')) return 'macos';
    if (lower.contains('windows') ||
        lower.contains('mingw') ||
        lower.contains('msys'))
      return 'windows';
    return lower.split(' ').first;
  }
}
