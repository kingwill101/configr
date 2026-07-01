import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' show posix;

/// mkdir-based host locking for multi-host deployment safety.
///
/// Uses atomic directory creation as a lock mechanism (pattern used by Kamal).
/// The lock directory is created atomically — if it already exists, the lock
/// is held by another process. This prevents concurrent deploys to the same
/// host from conflicting.
///
/// Lock directory structure:
/// ```
/// .configr/locks/<hostname>/
/// ```
class HostLock {
  final String baseDir;
  final FileSystem fs;

  HostLock({this.baseDir = '.configr', FileSystem? fs})
    : fs = fs ?? LocalFileSystem();

  /// Acquire a lock for [hostName].
  ///
  /// Returns `true` if the lock was acquired, `false` if already held.
  Future<bool> acquire(String hostName) async {
    final lockDir = _lockPath(hostName);
    if (await fs.directory(lockDir).exists()) {
      return false;
    }
    await fs.directory(lockDir).create(recursive: true);
    return true;
  }

  /// Acquire a lock for [hostName] asynchronously.
  Future<bool> acquireAsync(String hostName) async {
    return acquire(hostName);
  }

  /// Release the lock for [hostName].
  Future<void> release(String hostName) async {
    final lockDir = _lockPath(hostName);
    final dir = fs.directory(lockDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Release the lock for [hostName] asynchronously.
  Future<void> releaseAsync(String hostName) async {
    await release(hostName);
  }

  /// Check if a lock is held for [hostName].
  Future<bool> isLocked(String hostName) {
    return fs.directory(_lockPath(hostName)).exists();
  }

  /// Check if a lock is held for [hostName] asynchronously.
  Future<bool> isLockedAsync(String hostName) async {
    return isLocked(hostName);
  }

  /// Release all locks.
  Future<void> releaseAll() async {
    final locksDir = fs.directory(_locksDir());
    if (await locksDir.exists()) {
      await locksDir.delete(recursive: true);
    }
  }

  /// List all currently locked host names.
  Future<List<String>> lockedHosts() async {
    final locksDir = fs.directory(_locksDir());
    if (!await locksDir.exists()) return [];
    final entries = await locksDir.list().toList();
    return entries
        .whereType<Directory>()
        .map((d) => posix.basename(d.path))
        .toList();
  }

  String _locksDir() => posix.join(baseDir, 'locks');

  String _lockPath(String hostName) => posix.join(_locksDir(), hostName);
}
