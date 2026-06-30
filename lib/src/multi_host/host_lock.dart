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
  bool acquire(String hostName) {
    final lockDir = _lockPath(hostName);
    if (fs.directory(lockDir).existsSync()) {
      return false;
    }
    fs.directory(lockDir).createSync(recursive: true);
    return true;
  }

  /// Acquire a lock for [hostName] asynchronously.
  Future<bool> acquireAsync(String hostName) async {
    final lockDir = _lockPath(hostName);
    if (await fs.directory(lockDir).exists()) {
      return false;
    }
    await fs.directory(lockDir).create(recursive: true);
    return true;
  }

  /// Release the lock for [hostName].
  void release(String hostName) {
    final lockDir = _lockPath(hostName);
    final dir = fs.directory(lockDir);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  }

  /// Release the lock for [hostName] asynchronously.
  Future<void> releaseAsync(String hostName) async {
    final lockDir = _lockPath(hostName);
    final dir = fs.directory(lockDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Check if a lock is held for [hostName].
  bool isLocked(String hostName) {
    return fs.directory(_lockPath(hostName)).existsSync();
  }

  /// Check if a lock is held for [hostName] asynchronously.
  Future<bool> isLockedAsync(String hostName) async {
    return fs.directory(_lockPath(hostName)).exists();
  }

  /// Release all locks.
  void releaseAll() {
    final locksDir = fs.directory(_locksDir());
    if (locksDir.existsSync()) {
      locksDir.deleteSync(recursive: true);
    }
  }

  /// List all currently locked host names.
  List<String> lockedHosts() {
    final locksDir = fs.directory(_locksDir());
    if (!locksDir.existsSync()) return [];
    return locksDir
        .listSync()
        .whereType<Directory>()
        .map((d) => posix.basename(d.path))
        .toList();
  }

  String _locksDir() => posix.join(baseDir, 'locks');

  String _lockPath(String hostName) => posix.join(_locksDir(), hostName);
}
