import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:configr/src/di.dart';
import 'package:configr/src/utils/execution_service.dart';
import 'package:configr/src/utils/fs.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:configr/src/utils/privilege_escalation.dart';
import 'package:configr/src/utils/system_operations.dart';
import 'package:crypto/crypto.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';

/// Injectable file-system service that wraps [FileUtils]-style operations.
///
/// Blocks should depend on this interface instead of calling static
/// [FileUtils] methods directly, so the implementation can be swapped for
/// testing (MemoryFileSystem) or remote execution (SSHFileSystem).
abstract class FileService {
  Future<bool> fileExists(String path);
  Future<bool> directoryExists(String path);
  Future<({bool exists, bool isDir})> pathExists(String path);
  Future<String> readFile(String path);
  Future<List<int>> readBinaryFile(String path);
  Future<void> writeFile(String path, String content, {bool recursive = false});
  Future<void> deleteFile(String path);
  Future<void> deleteDirectory(String path, {bool recursive = true});
  Future<void> createDirectory(String path, {bool recursive = true});
  Future<void> copyFile(String source, String destination);
  Future<void> moveFile(String source, String destination);
  Future<void> createSymlink(String target, String link);
  Future<String?> readSymlink(String path);
  Future<bool> isSymlink(String path);
  Future<String> computeFileHash(String path, {bool recursive = false});
  Future<void> setOwner(String path, String owner);
  Future<Map<String, String>> chown(
    String path,
    String? owner,
    String? group, {
    PrivilegeEscalation? escalation,
  });
  Future<String> chmod(
    String path,
    String mode, {
    PrivilegeEscalation? escalation,
  });
  Future<Map<String, String>> getOwnership(String path);
  Future<String> getPermissions(String path);
  String generateBackupPath(String originalPath);
  Future<Directory> copyDir(
    String source,
    String destination, {
    bool recursive = false,
  });
  Future<ProcessResult> executeCommand(
    String command,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  });
  Future<void> writeFileWithPermissions(
    String path,
    String content, {
    bool requireElevation = false,
  });
  Future<void> createDirectoryWithPermissions(
    String path, {
    bool requireElevation = false,
  });
}

/// Concrete [FileService] backed by a [FileSystem].
///
/// Resolves [FileSystem] from the DI container lazily on first access, so the
/// same filesystem (local, memory, remote) is used everywhere and survives
/// DI reassignment in tests.
class LocalFileService implements FileService {
  final FileSystem? _explicitFs;

  LocalFileService({FileSystem? fileSystem}) : _explicitFs = fileSystem;

  FileSystem get _fs {
    if (_explicitFs != null) return _explicitFs;
    if (di.isRegistered<FileSystem>()) return di<FileSystem>();
    return fs;
  }

  ExecutionService get _executionService => di.isRegistered<ExecutionService>()
      ? di<ExecutionService>()
      : const LocalExecutionService();

  @override
  Future<bool> fileExists(String path) async {
    return _fs.file(path).exists();
  }

  @override
  Future<bool> directoryExists(String path) async {
    return _fs.directory(path).exists();
  }

  @override
  Future<({bool exists, bool isDir})> pathExists(String path) async {
    if (await _fs.file(path).exists()) {
      return (exists: true, isDir: false);
    }
    if (await _fs.directory(path).exists()) {
      return (exists: true, isDir: true);
    }
    return (exists: false, isDir: false);
  }

  @override
  Future<String> readFile(String path) async {
    return _fs.file(path).readAsString();
  }

  @override
  Future<List<int>> readBinaryFile(String path) async {
    return _fs.file(path).readAsBytes();
  }

  @override
  Future<void> writeFile(
    String path,
    String content, {
    bool recursive = false,
  }) async {
    if (recursive) {
      final dir = _fs.path.dirname(path);
      if (!await _fs.directory(dir).exists()) {
        await _fs.directory(dir).create(recursive: true);
      }
    }
    await _fs.file(path).writeAsString(content);
  }

  @override
  Future<void> deleteFile(String path) async {
    final file = _fs.file(path);
    if (await file.exists()) {
      await file.delete();
      logger.info('File $path deleted');
    }
  }

  @override
  Future<void> deleteDirectory(String path, {bool recursive = true}) async {
    final dir = _fs.directory(path);
    if (await dir.exists()) {
      await dir.delete(recursive: recursive);
      logger.info('Directory $path deleted');
    }
  }

  @override
  Future<void> createDirectory(String path, {bool recursive = true}) async {
    final dir = _fs.directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: recursive);
    }
  }

  @override
  Future<void> copyFile(String source, String destination) async {
    await _fs.file(source).copy(destination);
    logger.info('File copied from $source to $destination');
  }

  @override
  Future<void> moveFile(String source, String destination) async {
    final src = _fs.file(source);
    if (await src.exists()) {
      await src.copy(destination);
      await src.delete();
      logger.info('File moved from $source to $destination');
    }
  }

  @override
  Future<void> createSymlink(String target, String link) async {
    await _fs.link(link).create(target);
  }

  @override
  Future<String?> readSymlink(String path) async {
    try {
      final link = _fs.link(path);
      if (await link.exists()) {
        return link.targetSync();
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<bool> isSymlink(String path) async {
    return _fs.isLink(path);
  }

  @override
  Future<String> computeFileHash(String path, {bool recursive = false}) async {
    final entity = _fs.statSync(path);
    if (entity.type == FileSystemEntityType.file) {
      final contents = await _fs.file(path).readAsBytes();
      return sha256.convert([...utf8.encode(path), ...contents]).toString();
    } else if (entity.type == FileSystemEntityType.directory) {
      final dir = _fs.directory(path);
      final childEntities = dir.listSync(recursive: recursive);
      childEntities.sort((a, b) => a.path.compareTo(b.path));
      var digest = sha256.convert(utf8.encode(path));
      for (final child in childEntities) {
        final relativePath = _fs.path.relative(child.path, from: path);
        digest = sha256.convert([
          ...digest.bytes,
          ...utf8.encode(relativePath),
        ]);
        if (!recursive || child is! Directory) {
          final childHash = await computeFileHash(child.path, recursive: false);
          digest = sha256.convert([...digest.bytes, ...utf8.encode(childHash)]);
        }
      }
      return digest.toString();
    } else if (entity.type == FileSystemEntityType.link) {
      final target = await _fs.link(path).target();
      return sha256.convert([
        ...utf8.encode(path),
        ...utf8.encode(target),
      ]).toString();
    }
    throw FileSystemException('Unsupported entity type', path);
  }

  @override
  Future<void> setOwner(String path, String owner) async {
    final result = await _executionService.run('chown', [
      owner,
      path,
    ], runInShell: true);
    if (result.exitCode != 0) {
      throw ProcessException(
        'chown',
        [owner, path],
        result.stderr.toString(),
        result.exitCode,
      );
    }
    logger.info('Set owner of $path to $owner');
  }

  @override
  Future<Map<String, String>> chown(
    String path,
    String? owner,
    String? group, {
    PrivilegeEscalation? escalation,
  }) async {
    final current = await getOwnership(path);
    if (owner == null && group == null) {
      throw ArgumentError('Both owner and group cannot be null');
    }
    final chownArg = owner != null && group != null
        ? '$owner:$group'
        : owner ?? ':$group';
    final result = escalation != null
        ? await escalation.runWithElevatedPrivileges('chown', [chownArg, path])
        : await _executionService.run('chown', [
            chownArg,
            path,
          ], runInShell: true);
    if (result.exitCode != 0) {
      throw ProcessException(
        'chown',
        [chownArg, path],
        result.stderr.toString(),
        result.exitCode,
      );
    }
    logger.info('Ownership changed for $path');
    return current;
  }

  @override
  Future<String> chmod(
    String path,
    String mode, {
    PrivilegeEscalation? escalation,
  }) async {
    final current = await getPermissions(path);
    final result = escalation != null
        ? await escalation.runWithElevatedPrivileges('chmod', [mode, path])
        : await _executionService.run('chmod', [mode, path], runInShell: true);
    if (result.exitCode != 0) {
      throw ProcessException(
        'chmod',
        [mode, path],
        result.stderr.toString(),
        result.exitCode,
      );
    }
    logger.info('Permissions of $path changed to $mode');
    return current;
  }

  @override
  Future<Map<String, String>> getOwnership(String path) async {
    final ops = SystemOperations(_executionService.platform);
    final (cmd, args) = ops.getOwnership(path);
    final result = await _executionService.run(cmd, args, runInShell: true);
    if (result.exitCode != 0) {
      throw ProcessException(
        cmd,
        args,
        result.stderr.toString(),
        result.exitCode,
      );
    }
    final parts = (result.stdout as String).trim().split(' ');
    return {'owner': parts[0], 'group': parts[1]};
  }

  @override
  Future<String> getPermissions(String path) async {
    final ops = SystemOperations(_executionService.platform);
    final (cmd, args) = ops.getPermissions(path);
    final result = await _executionService.run(cmd, args, runInShell: true);
    if (result.exitCode != 0) {
      throw ProcessException(
        cmd,
        args,
        result.stderr.toString(),
        result.exitCode,
      );
    }
    return (result.stdout as String).trim();
  }

  @override
  String generateBackupPath(String originalPath) {
    final dir = _fs.path.dirname(originalPath);
    final name = _fs.path.basenameWithoutExtension(originalPath);
    final ext = _fs.path.extension(originalPath);
    final ts = DateTime.now().toIso8601String().replaceAll(':', '');
    return _fs.path.join(dir, '$name.bak.$ts$ext');
  }

  @override
  Future<Directory> copyDir(
    String source,
    String destination, {
    bool recursive = false,
  }) async {
    final src = _fs.directory(source);
    final dst = _fs.directory(destination);
    if (!await src.exists()) {
      throw FileSystemException('Source directory does not exist', source);
    }
    if (!await dst.exists()) {
      await dst.create(recursive: true);
    }
    for (final entity in src.listSync(recursive: recursive)) {
      final relativePath = _fs.path.relative(entity.path, from: source);
      final targetPath = _fs.path.join(destination, relativePath);
      if (entity is Directory) {
        final targetDir = _fs.directory(targetPath);
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
      } else if (entity is File) {
        final targetDir = _fs.directory(_fs.path.dirname(targetPath));
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
        await entity.copy(targetPath);
      } else if (entity is Link) {
        final targetDir = _fs.directory(_fs.path.dirname(targetPath));
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
        await _fs.link(targetPath).create(await entity.target());
      }
    }
    return dst;
  }

  @override
  Future<ProcessResult> executeCommand(
    String command,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    return _executionService.run(
      command,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
    );
  }

  @override
  Future<void> writeFileWithPermissions(
    String path,
    String content, {
    bool requireElevation = false,
  }) async {
    final escalation = _escalation;
    final dir = _fs.path.dirname(path);
    if (!await directoryExists(dir)) {
      if (escalation != null) {
        await createDirectoryWithPermissions(
          dir,
          requireElevation: requireElevation,
        );
      } else {
        await createDirectory(dir, recursive: true);
      }
    }
    if (!requireElevation) {
      try {
        await _fs.file(path).writeAsString(content);
        return;
      } catch (e) {
        if (_isPermissionException(e) && escalation != null) {
          requireElevation = true;
        } else {
          rethrow;
        }
      }
    }
    if (escalation == null) {
      throw Exception(
        'Permission denied and no privilege escalation available for: $path',
      );
    }
    final tempFile = _fs.systemTempDirectory.createTempSync().childFile(
      'configr_temp_${DateTime.now().millisecondsSinceEpoch}',
    );
    tempFile.writeAsStringSync(content);
    try {
      await escalation.runWithElevatedPrivileges('cp', [tempFile.path, path]);
      await escalation.runWithElevatedPrivileges('chmod', ['644', path]);
    } finally {
      if (await tempFile.exists()) tempFile.deleteSync();
    }
  }

  @override
  Future<void> createDirectoryWithPermissions(
    String path, {
    bool requireElevation = false,
  }) async {
    final dir = _fs.directory(path);
    if (await dir.exists()) return;
    if (!requireElevation) {
      try {
        await dir.create(recursive: true);
        return;
      } catch (e) {
        if (_isPermissionException(e)) {
          requireElevation = true;
        } else {
          rethrow;
        }
      }
    }
    if (!requireElevation) return;
    final escalation = _escalation;
    if (escalation == null) {
      throw Exception(
        'Permission denied and no privilege escalation available for: $path',
      );
    }
    await escalation.runWithElevatedPrivileges('mkdir', ['-p', path]);
  }

  PrivilegeEscalation? get _escalation =>
      di.isRegistered<PrivilegeEscalation>() ? di<PrivilegeEscalation>() : null;
}

bool _isPermissionException(dynamic e) {
  if (e is ProcessException) {
    final msg = e.message.toLowerCase();
    return msg.contains('permission denied') || msg.contains('access denied');
  }
  if (e is FileSystemException) {
    return e.osError?.errorCode == 13;
  }
  return false;
}

/// [FileService] backed by a [MemoryFileSystem] for testing.
class MemoryFileService extends LocalFileService {
  MemoryFileService({required super.fileSystem});
}
