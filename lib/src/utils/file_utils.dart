import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:io';

import 'package:configr/src/utils/fs.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:configr/src/utils/privilege_escalation.dart';
import 'package:crypto/crypto.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as p;

/// Utility class containing file system related helper methods
class FileUtils {
  /// Check if the current platform is Unix-like (Linux, macOS, etc.)
  static bool get isUnixLike => Platform.isLinux || Platform.isMacOS;

  /// Check if the current platform is Windows
  static bool get isWindows => Platform.isWindows;

  /// Copies a file from source path to destination path
  /// Returns the copied File
  static Future<File> copyFile(
    String source,
    String destination, {
    FileSystem? fileSystem,
  }) async {
    Completer<File> completer = Completer();
    logger.info('Copying file from $source to $destination');
    (fileSystem ?? fs)
        .file(source)
        .copy(destination)
        .then((f) {
          logger.info('File copied successfully');
          completer.complete(f);
        })
        .catchError((err, stacktrace) {
          logger.error('File not copied successfully', err, stacktrace);
          completer.completeError(err, stacktrace);
        });

    return completer.future;
  }

  /// Checks if a directory exists at the given path
  /// Returns true if directory exists, false otherwise
  static Future<bool> directoryExists(
    String path, {
    FileSystem? fileSystem,
  }) async {
    Completer<bool> completer = Completer();
    (fileSystem ?? fs)
        .directory(path)
        .exists()
        .then((exists) {
          completer.complete(exists);
        })
        .catchError((err, stacktrace) {
          completer.completeError(err, stacktrace);
        });
    return completer.future;
  }

  /// Checks if a file exists at the given path
  /// Returns true if file exists, false otherwise
  static Future<bool> fileExists(String path, {FileSystem? fileSystem}) async {
    Completer<bool> completer = Completer();
    final file = (fileSystem ?? fs).file(path);
    file
        .exists()
        .then((exists) {
          completer.complete(exists);
        })
        .catchError((err, stacktrace) {
          completer.completeError(err, stacktrace);
        });
    return completer.future;
  }

  /// Checks if a path exists and whether it's a directory
  /// Returns tuple of (exists, isDirectory)
  static Future<({bool exists, bool isDir})> pathExists(
    String path, {
    FileSystem? fileSystem,
  }) async {
    Completer<({bool exists, bool isDir})> completer = Completer();

    fileExists(path, fileSystem: fileSystem)
        .then((exists) {
          if (exists) {
            completer.complete((exists: true, isDir: false));
          } else {
            directoryExists(path, fileSystem: fileSystem)
                .then((exists) {
                  if (exists) {
                    completer.complete((exists: true, isDir: true));
                  } else {
                    completer.complete((exists: false, isDir: false));
                  }
                })
                .catchError((err, stacktrace) {
                  completer.completeError(err, stacktrace);
                });
          }
        })
        .catchError((err, stacktrace) {
          completer.completeError(err, stacktrace);
        });

    return completer.future;
  }

  /// Deletes a file at the given path
  static Future deleteFile(String path, {FileSystem? fileSystem}) async {
    Completer<void> completer = Completer();
    final file = (fileSystem ?? fs).file(path);
    file
        .exists()
        .then((exists) async {
          if (exists) {
            await file.delete();
            logger.info('File $path deleted');
          } else {
            logger.info('File $path does not exist');
          }
          completer.complete();
        })
        .catchError((err, stacktrace) {
          completer.completeError(err, stacktrace);
        });
    return completer.future;
  }

  /// Deletes a directory and optionally its contents recursively
  static Future<void> deleteDirectory(
    String path, {
    FileSystem? fileSystem,
    bool recursive = true,
  }) async {
    Completer<void> completer = Completer();
    final directory = (fileSystem ?? fs).directory(path);
    directory
        .exists()
        .then((exists) async {
          if (exists) {
            await directory.delete(recursive: recursive);
            logger.info('Directory $path deleted');
          } else {
            logger.info('Directory $path does not exist');
          }
          completer.complete();
        })
        .catchError((err, stacktrace) {
          completer.completeError(err, stacktrace);
        });
    return completer.future;
  }

  /// Creates a new directory at the given path
  /// Returns the created Directory
  static Future<io.Directory> createDirectory(
    String path, {
    FileSystem? fileSystem,
    bool recursive = true,
  }) async {
    Completer<io.Directory> completer = Completer();
    final directory = (fileSystem ?? fs).directory(path);
    directory
        .exists()
        .then((exists) async {
          if (exists) {
            logger.info('Directory $path already exists');
          } else {
            logger.info('Directory $path does not exist');
            directory.createSync(recursive: recursive);
            if (!directory.existsSync()) {
              throw Exception("Directory $path does not exist");
            }
          }
          completer.complete(directory);
        })
        .catchError((err, stacktrace) {
          logger.error('Failed to create directory $path', err, stacktrace);
          completer.completeError(err, stacktrace);
        });
    return completer.future;
  }

  /// Changes the owner of a file
  static Future<void> setOwner(
    String filePath,
    String owner, {
    FileSystem? fileSystem,
  }) async {
    final result = await Process.run('chown', [
      owner,
      filePath,
    ], runInShell: true);
    if (result.exitCode != 0) {
      throw ProcessException(
        'chown',
        [owner, filePath],
        result.stderr.toString(),
        result.exitCode,
      );
    }
    logger.info('Set owner of $filePath to $owner');
  }

  /// Generates a backup path with timestamp for a given file path
  static String generateBackupPath(String originalPath) {
    final dir = p.dirname(originalPath);
    final name = p.basenameWithoutExtension(originalPath);
    final extension = p.extension(originalPath);
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '');
    return p.join(dir, '$name.bak.$timestamp$extension');
  }

  /// Creates a symbolic link pointing to target at link path
  static Future<void> createSymlink(
    String target,
    String link, {
    FileSystem? fileSystem,
  }) async {
    Completer<void> completer = Completer();
    (fileSystem ?? fs)
        .link(link)
        .create(target)
        .then((_) {
          completer.complete();
        })
        .catchError((err, stacktrace) {
          completer.completeError(err, stacktrace);
        });
    return completer.future;
  }

  /// Computes a SHA-256 hash that represents the state of a filesystem entity
  /// - For files: hashes the content
  /// - For directories: hashes the names and hashes of immediate children
  /// - For symlinks: hashes the target path
  static Future<String> computeFileHash(
    String path, {
    FileSystem? fileSystem,
    bool recursive = false,
  }) async {
    final fsToUse = fileSystem ?? fs;
    final entity = fsToUse.statSync(path);

    if (entity.type == FileSystemEntityType.file) {
      // For regular files, hash the contents and path
      final contents = await fsToUse.file(path).readAsBytes();

      return sha256.convert([...utf8.encode(path), ...contents]).toString();
    } else if (entity.type == FileSystemEntityType.directory) {
      // For directories, combine hashes of children
      final dir = fsToUse.directory(path);
      final childEntities = dir.listSync(recursive: recursive);

      // Sort to ensure consistent ordering
      childEntities.sort((a, b) => a.path.compareTo(b.path));

      // Start with the directory path
      var digest = sha256.convert(utf8.encode(path));

      for (final child in childEntities) {
        // Add the relative path to capture directory structure
        final relativePath = p.relative(child.path, from: path);

        // Combine current digest with path
        digest = sha256.convert([
          ...digest.bytes,
          ...utf8.encode(relativePath),
        ]);

        if (!recursive || child is! Directory) {
          // If not recursive or if it's a file/link, compute its hash
          final childHash = await computeFileHash(
            child.path,
            fileSystem: fsToUse,
            recursive: false,
          );

          // Combine current digest with child hash
          digest = sha256.convert([...digest.bytes, ...utf8.encode(childHash)]);
        }
      }

      return digest.toString();
    } else if (entity.type == FileSystemEntityType.link) {
      // For symlinks, hash both the link path and target path
      final target = await fsToUse.link(path).target();

      return sha256.convert([
        ...utf8.encode(path),
        ...utf8.encode(target),
      ]).toString();
    } else {
      throw FileSystemException('Unsupported file system entity type', path);
    }
  }

  /// Moves a file from source to destination path
  static Future<void> moveFile(
    String source,
    destinationPath, {
    FileSystem? fileSystem,
  }) async {
    Completer<void> completer = Completer();
    final sourceFile = (fileSystem ?? fs).file(source);
    sourceFile
        .exists()
        .then((exists) async {
          if (exists) {
            await sourceFile.copy(destinationPath);
            await sourceFile.delete();
            logger.info('File $source moved to $destinationPath');
          } else {
            logger.warning('File $source does not exist');
          }
          completer.complete();
        })
        .catchError((err, stacktrace) {
          completer.completeError(err, stacktrace);
        });
    return completer.future;
  }

  /// Changes the ownership of a file and returns the original ownership
  /// Can use elevated privileges if provided
  static Future<Map<String, String>> chown(
    String destinationPath,
    String? owner,
    String? group, {
    FileSystem? fileSystem,
    PrivilegeEscalation? privilegeEscalation,
  }) async {
    // Get current ownership before changing it
    final currentOwnership = await getOwnership(destinationPath);

    if (owner == null && group == null) {
      throw ArgumentError('Both owner and group cannot be null');
    }

    // Construct the chown argument for Unix systems
    String chownArg = '';
    if (owner != null && group != null) {
      chownArg = '$owner:$group';
    } else if (owner != null) {
      chownArg = owner;
    } else if (group != null) {
      chownArg = ":$group";
    }

    try {
      final result = privilegeEscalation != null
          ? await privilegeEscalation.runWithElevatedPrivileges('chown', [
              chownArg,
              destinationPath,
            ])
          : await Process.run('chown', [
              chownArg,
              destinationPath,
            ], runInShell: true);

      if (result.exitCode != 0) {
        throw ProcessException(
          'chown',
          [chownArg, destinationPath],
          result.stderr.toString(),
          result.exitCode,
        );
      }
    } catch (e) {
      logger.info('Failed to change ownership of $destinationPath: $e');
      rethrow;
    }

    logger.info('Ownership changed for $destinationPath');
    return currentOwnership;
  }

  /// Changes file permissions and returns original permissions
  /// Can use elevated privileges if provided
  static Future<String> chmod(
    String destinationPath,
    String mode, {
    FileSystem? fileSystem,
    PrivilegeEscalation? privilegeEscalation,
  }) async {
    // Get current permissions before changing them
    final currentPermissions = await getPermissions(destinationPath);

    // Run the chmod command
    try {
      final result = privilegeEscalation != null
          ? await privilegeEscalation.runWithElevatedPrivileges('chmod', [
              mode,
              destinationPath,
            ])
          : await Process.run('chmod', [
              mode,
              destinationPath,
            ], runInShell: true);

      if (result.exitCode != 0) {
        throw ProcessException(
          'chmod',
          [mode, destinationPath],
          result.stderr.toString(),
          result.exitCode,
        );
      }

      logger.info('Permissions of $destinationPath changed to $mode');
    } catch (e) {
      logger.info('Failed to change permissions of $destinationPath: $e');
      rethrow;
    }

    // Return the current permissions for rollback purposes
    return currentPermissions;
  }

  /// Gets current owner and group of a file
  static Future<Map<String, String>> getOwnership(
    String destinationPath,
  ) async {
    try {
      // Use stat to get ownership details
      // %U = owner name, %G = group name
      final result = await Process.run('stat', [
        '-c',
        '%U %G',
        destinationPath,
      ], runInShell: true);

      if (result.exitCode != 0) {
        throw ProcessException(
          'stat',
          ['-c', '%U %G', destinationPath],
          result.stderr.toString(),
          result.exitCode,
        );
      }

      final parts = result.stdout.trim().split(' ');
      if (parts.length != 2) {
        throw FormatException(
          'Unexpected stat output format: ${result.stdout}',
        );
      }

      return {'owner': parts[0], 'group': parts[1]};
    } catch (e) {
      logger.error('Failed to retrieve ownership for $destinationPath: $e');
      rethrow;
    }
  }

  /// Gets current permissions of a file in octal format
  static Future<String> getPermissions(String destinationPath) async {
    try {
      // Run `stat` to get the permissions in numeric format
      final result = await Process.run('stat', [
        '-c',
        '%a',
        destinationPath,
      ], runInShell: true);

      if (result.exitCode != 0) {
        throw ProcessException(
          'stat',
          ['-c', '%a', destinationPath],
          result.stderr.toString(),
          result.exitCode,
        );
      }

      // Return the permissions as a string
      return result.stdout.trim();
    } catch (e) {
      logger.info('Failed to retrieve permissions for $destinationPath: $e');
      rethrow;
    }
  }

  /// Checks if a path is a symbolic link
  static Future<bool> isSymlink(
    dynamic symlinkPath, {
    FileSystem? fileSystem,
  }) async {
    return await (fileSystem ?? fs).isLink(symlinkPath);
  }

  /// Gets the target path that a symbolic link points to
  static Future<String?> readSymlink(
    String symlinkPath, {
    FileSystem? fileSystem,
  }) async {
    try {
      final link = (fileSystem ?? fs).link(symlinkPath);

      // Check if the provided path is actually a symlink
      if (!await link.exists()) {
        throw FileSystemException(
          'The specified path is not a valid symlink',
          symlinkPath,
        );
      }

      // Resolve the symlink target
      final targetPath = await link.target();
      logger.info('Symlink $symlinkPath points to $targetPath');

      return targetPath;
    } catch (e) {
      logger.info('Failed to read symlink $symlinkPath: $e');
      return null;
    }
  }

  /// Recursively copies a directory and its contents
  static Future<Directory> copyDir(
    String source,
    String destination, {
    FileSystem? fileSystem,
    bool recursive = false,
  }) async {
    final fsToUse = fileSystem ?? fs;
    final sourceDir = fsToUse.directory(source);
    final destinationDir = fsToUse.directory(destination);

    // Ensure the source directory exists
    if (!sourceDir.existsSync()) {
      throw FileSystemException('Source directory does not exist', source);
    }

    // Ensure the destination directory exists
    if (!destinationDir.existsSync()) {
      await destinationDir.create(recursive: true);
    }

    // List the contents of the source directory
    for (var entity in sourceDir.listSync(recursive: recursive)) {
      if (entity is Directory) {
        // Recursively copy subdirectories
        final newDir = p.join(destination, p.basename(entity.path));
        await copyDir(
          newDir,
          entity.path,
          fileSystem: fileSystem,
          recursive: recursive,
        );
      } else if (entity is File) {
        // Copy files
        final newFile = p.join(destination, p.basename(entity.path));
        await entity.copy(newFile);
      }
    }
    return Future.value(destinationDir);
  }

  /// Reads entire contents of a file as a string
  static Future<String> readFile(String path, {FileSystem? fileSystem}) async {
    final fsToUse = fileSystem ?? fs;

    return await fsToUse.file(path).readAsString();
  }

  /// Reads entire contents of a file as bytes
  static Future<List<int>> readBinaryFile(
    String path, {
    FileSystem? fileSystem,
  }) async {
    final fsToUse = fileSystem ?? fs;

    return await fsToUse.file(path).readAsBytes();
  }

  /// Writes string content to a file, creating parent directories if needed
  static Future<void> writeFile(
    String path,
    String content, {
    FileSystem? fileSystem,
    bool recursive = false,
  }) async {
    final fsToUse = fileSystem ?? fs;
    final dir = p.dirname(path);
    final dirExists = await directoryExists(dir, fileSystem: fileSystem);

    if (!dirExists && recursive) {
      logger.info("creating destination dir $dir");
      await createDirectory(dir, fileSystem: fileSystem);
    }
    await fsToUse.file(path).writeAsString(content);
  }

  /// Permission-aware file writing with automatic privilege escalation fallback
  static Future<void> writeFileWithPermissions(
    String path,
    String content, {
    FileSystem? fileSystem,
    bool recursive = false,
    PrivilegeEscalation? privilegeEscalation,
    bool requireElevation = false,
  }) async {
    logger.info('Writing file with permission awareness: $path');

    try {
      // Create parent directory if needed
      final dir = p.dirname(path);
      final dirExists = await directoryExists(dir, fileSystem: fileSystem);

      if (!dirExists && recursive) {
        await createDirectoryWithPermissions(
          dir,
          fileSystem: fileSystem,
          privilegeEscalation: privilegeEscalation,
          requireElevation: requireElevation,
        );
      }

      // Try direct write first
      if (!requireElevation) {
        try {
          await writeFile(
            path,
            content,
            fileSystem: fileSystem,
            recursive: false,
          );
          logger.info('File written successfully: $path');
          return;
        } catch (e) {
          if (_isPermissionException(e)) {
            logger.warning(
              'Permission denied for direct write, trying with privilege escalation: $path',
            );
            requireElevation = true;
          } else {
            rethrow;
          }
        }
      }

      // Try with privilege escalation if needed
      if (requireElevation && privilegeEscalation != null) {
        try {
          // Write to temp file first, then move with privilege escalation
          final tempFile = (fileSystem ?? fs).systemTempDirectory
              .createTempSync()
              .childFile(
                'configr_temp_${DateTime.now().millisecondsSinceEpoch}',
              );
          tempFile.writeAsStringSync(content);

          await privilegeEscalation.runWithElevatedPrivileges('cp', [
            tempFile.path,
            path,
          ]);
          await privilegeEscalation.runWithElevatedPrivileges('chmod', [
            '644',
            path,
          ]);

          tempFile.deleteSync();
          logger.info(
            'File written successfully with privilege escalation: $path',
          );
        } catch (e) {
          logger.error(
            'Failed to write file with privilege escalation: $path - $e',
          );
          throw Exception('Failed to write file with privilege escalation: $e');
        }
      } else {
        throw Exception(
          'Permission denied and no privilege escalation available for: $path',
        );
      }
    } catch (e) {
      logger.error('Failed to write file: $path - $e');
      rethrow;
    }
  }

  /// Permission-aware directory creation with automatic privilege escalation fallback
  static Future<void> createDirectoryWithPermissions(
    String path, {
    FileSystem? fileSystem,
    bool recursive = true,
    PrivilegeEscalation? privilegeEscalation,
    bool requireElevation = false,
  }) async {
    logger.info('Creating directory with permission awareness: $path');

    // Check if directory already exists
    final dirExists = await directoryExists(path, fileSystem: fileSystem);
    if (dirExists) {
      logger.info('Directory already exists: $path');
      return;
    }

    try {
      // Try direct creation first
      if (!requireElevation) {
        try {
          await createDirectory(
            path,
            fileSystem: fileSystem,
            recursive: recursive,
          );
          logger.info('Directory created successfully: $path');
          return;
        } catch (e) {
          if (_isPermissionException(e)) {
            logger.warning(
              'Permission denied for direct creation, trying with privilege escalation: $path',
            );
            requireElevation = true;
          } else {
            rethrow;
          }
        }
      }

      // Try with privilege escalation if needed
      if (requireElevation && privilegeEscalation != null) {
        try {
          final args = recursive ? ['-p', path] : [path];
          await privilegeEscalation.runWithElevatedPrivileges('mkdir', args);
          logger.info(
            'Directory created successfully with privilege escalation: $path',
          );
        } catch (e) {
          logger.error(
            'Failed to create directory with privilege escalation: $path - $e',
          );
          throw Exception(
            'Failed to create directory with privilege escalation: $e',
          );
        }
      } else {
        throw Exception(
          'Permission denied and no privilege escalation available for: $path',
        );
      }
    } catch (e) {
      logger.error('Failed to create directory: $path - $e');
      rethrow;
    }
  }

  /// Permission-aware file deletion with automatic privilege escalation fallback
  static Future<void> deleteFileWithPermissions(
    String path, {
    FileSystem? fileSystem,
    PrivilegeEscalation? privilegeEscalation,
    bool requireElevation = false,
  }) async {
    logger.info('Deleting file with permission awareness: $path');

    // Check if file exists
    final fileExistsCheck = await fileExists(path, fileSystem: fileSystem);
    if (!fileExistsCheck) {
      logger.info('File does not exist: $path');
      return;
    }

    try {
      // Try direct deletion first
      if (!requireElevation) {
        try {
          await deleteFile(path, fileSystem: fileSystem);
          logger.info('File deleted successfully: $path');
          return;
        } catch (e) {
          if (_isPermissionException(e)) {
            logger.warning(
              'Permission denied for direct deletion, trying with privilege escalation: $path',
            );
            requireElevation = true;
          } else {
            rethrow;
          }
        }
      }

      // Try with privilege escalation if needed
      if (requireElevation && privilegeEscalation != null) {
        try {
          await privilegeEscalation.runWithElevatedPrivileges('rm', [path]);
          logger.info(
            'File deleted successfully with privilege escalation: $path',
          );
        } catch (e) {
          logger.error(
            'Failed to delete file with privilege escalation: $path - $e',
          );
          throw Exception(
            'Failed to delete file with privilege escalation: $e',
          );
        }
      } else {
        throw Exception(
          'Permission denied and no privilege escalation available for: $path',
        );
      }
    } catch (e) {
      logger.error('Failed to delete file: $path - $e');
      rethrow;
    }
  }

  /// Check if a file or directory has the required permissions
  static Future<PermissionCheckResult> checkPermissions(
    String path, {
    bool requireRead = false,
    bool requireWrite = false,
    bool requireExecute = false,
    FileSystem? fileSystem,
  }) async {
    logger.info('Checking permissions for: $path');

    try {
      final fsToUse = fileSystem ?? fs;
      final file = fsToUse.file(path);
      final directory = fsToUse.directory(path);

      // Check if path exists
      final exists = file.existsSync() || directory.existsSync();
      if (!exists) {
        return PermissionCheckResult(
          path: path,
          exists: false,
          canRead: false,
          canWrite: false,
          canExecute: false,
          isDirectory: false,
        );
      }

      final isDir = directory.existsSync();

      // Check read permission
      bool canRead = false;
      if (requireRead) {
        try {
          if (isDir) {
            directory.listSync().length; // Try to list contents
            canRead = true;
          } else {
            file.readAsStringSync();
            canRead = true;
          }
        } catch (e) {
          canRead = false;
        }
      }

      // Check write permission
      bool canWrite = false;
      if (requireWrite) {
        try {
          if (isDir) {
            final testFile = fsToUse.file(
              '$path/.permission_test_${DateTime.now().millisecondsSinceEpoch}',
            );
            testFile.writeAsStringSync('test');
            testFile.deleteSync();
            canWrite = true;
          } else {
            final backup = file.existsSync() ? file.readAsStringSync() : null;
            file.writeAsStringSync('test');
            if (backup != null) {
              file.writeAsStringSync(backup);
            } else {
              file.deleteSync();
            }
            canWrite = true;
          }
        } catch (e) {
          canWrite = false;
        }
      }

      // Check execute permission
      bool canExecute = false;
      if (requireExecute) {
        try {
          final result = await Process.run('test', ['-x', path]);
          canExecute = result.exitCode == 0;
        } catch (e) {
          canExecute = false;
        }
      }

      final result = PermissionCheckResult(
        path: path,
        exists: true,
        canRead: canRead,
        canWrite: canWrite,
        canExecute: canExecute,
        isDirectory: isDir,
      );

      logger.info(
        'Permission check result for $path: read=$canRead, write=$canWrite, execute=$canExecute',
      );
      return result;
    } catch (e) {
      logger.warning('Permission check failed for $path: $e');
      return PermissionCheckResult(
        path: path,
        exists: false,
        canRead: false,
        canWrite: false,
        canExecute: false,
        isDirectory: false,
        error: e.toString(),
      );
    }
  }

  /// Execute a command with permission awareness and automatic privilege escalation fallback
  static Future<ProcessResult> executeCommandWithPermissions(
    String command,
    List<String> arguments, {
    bool requireElevation = false,
    PrivilegeEscalation? privilegeEscalation,
    String? workingDirectory,
    Map<String, String>? environment,
    String? description,
  }) async {
    final cmdDesc = description ?? '$command ${arguments.join(' ')}';
    logger.info('Executing command with permission awareness: $cmdDesc');

    try {
      // First, try direct execution
      if (!requireElevation) {
        try {
          final result = await Process.run(
            command,
            arguments,
            workingDirectory: workingDirectory,
            environment: environment,
          );

          if (result.exitCode == 0) {
            logger.info('Command executed successfully: $cmdDesc');
            return result;
          }

          // Check if it's a permission error
          if (_isPermissionError(result)) {
            logger.warning(
              'Permission denied for command: $cmdDesc, trying with privilege escalation',
            );
            requireElevation = true;
          } else {
            logger.warning(
              'Command failed with exit code ${result.exitCode}: $cmdDesc',
            );
            return result;
          }
        } catch (e) {
          if (_isPermissionException(e)) {
            logger.warning(
              'Permission exception for command: $cmdDesc, trying with privilege escalation',
            );
            requireElevation = true;
          } else {
            rethrow;
          }
        }
      }

      // Try with privilege escalation if needed
      if (requireElevation && privilegeEscalation != null) {
        try {
          final result = await privilegeEscalation.runWithElevatedPrivileges(
            command,
            arguments,
          );

          if (result.exitCode == 0) {
            logger.info(
              'Command executed successfully with privilege escalation: $cmdDesc',
            );
            return result;
          } else {
            logger.error(
              'Command failed with privilege escalation (exit code ${result.exitCode}): $cmdDesc',
            );
            throw Exception(
              'Command failed with privilege escalation: $cmdDesc\n'
              'Exit code: ${result.exitCode}\n'
              'Stderr: ${result.stderr}',
            );
          }
        } catch (e) {
          logger.error('Privilege escalation failed for command: $cmdDesc');
          throw Exception(
            'Failed to execute command with privilege escalation: $cmdDesc\n'
            'Error: $e',
          );
        }
      }

      throw Exception('Unexpected execution path for command: $cmdDesc');
    } catch (e) {
      logger.error('Command execution failed: $cmdDesc - $e');
      rethrow;
    }
  }

  /// Check if a ProcessResult indicates a permission error
  static bool _isPermissionError(ProcessResult result) {
    final stderr = result.stderr.toString().toLowerCase();
    return stderr.contains('permission denied') ||
        stderr.contains('access denied') ||
        stderr.contains('operation not permitted') ||
        result.exitCode == 13; // Permission denied
  }

  /// Check if an exception is permission-related
  static bool _isPermissionException(dynamic exception) {
    if (exception is ProcessException) {
      return exception.message.toLowerCase().contains('permission denied') ||
          exception.message.toLowerCase().contains('access denied');
    }
    if (exception is FileSystemException) {
      return exception.osError?.errorCode == 13; // Permission denied
    }
    return false;
  }

  /// Check if an exception is permission-related (public version)
  static bool isPermissionError(dynamic exception) {
    return _isPermissionException(exception);
  }

  /// Cross-platform permission checking that works on all platforms
  static Future<PermissionCheckResult> checkPermissionsCrossPlatform(
    String path, {
    bool requireRead = false,
    bool requireWrite = false,
    bool requireExecute = false,
    FileSystem? fileSystem,
  }) async {
    logger.info('Checking permissions (cross-platform) for: $path');

    try {
      final fsToUse = fileSystem ?? fs;
      final file = fsToUse.file(path);
      final directory = fsToUse.directory(path);

      // Check if path exists
      final exists = file.existsSync() || directory.existsSync();
      if (!exists) {
        return PermissionCheckResult(
          path: path,
          exists: false,
          canRead: false,
          canWrite: false,
          canExecute: false,
          isDirectory: false,
        );
      }

      final isDir = directory.existsSync();

      // Check read permission (cross-platform)
      bool canRead = false;
      if (requireRead) {
        try {
          if (isDir) {
            directory.listSync().length; // Try to list contents
            canRead = true;
          } else {
            file.readAsStringSync();
            canRead = true;
          }
        } catch (e) {
          canRead = false;
        }
      }

      // Check write permission (cross-platform)
      bool canWrite = false;
      if (requireWrite) {
        try {
          if (isDir) {
            final testFile = fsToUse.file(
              '$path/.permission_test_${DateTime.now().millisecondsSinceEpoch}',
            );
            testFile.writeAsStringSync('test');
            testFile.deleteSync();
            canWrite = true;
          } else {
            final backup = file.existsSync() ? file.readAsStringSync() : null;
            file.writeAsStringSync('test');
            if (backup != null) {
              file.writeAsStringSync(backup);
            } else {
              file.deleteSync();
            }
            canWrite = true;
          }
        } catch (e) {
          canWrite = false;
        }
      }

      // Check execute permission (cross-platform)
      bool canExecute = false;
      if (requireExecute) {
        try {
          if (isUnixLike) {
            // Use Unix-specific test command
            final result = await Process.run('test', ['-x', path]);
            canExecute = result.exitCode == 0;
          } else if (isWindows) {
            // On Windows, check if file has .exe extension or is a directory
            if (isDir) {
              canExecute = true; // Directories are "executable" on Windows
            } else {
              final extension = p.extension(path).toLowerCase();
              canExecute =
                  extension == '.exe' ||
                  extension == '.bat' ||
                  extension == '.cmd';
            }
          } else {
            // Fallback: assume executable if we can read it
            canExecute = canRead;
          }
        } catch (e) {
          canExecute = false;
        }
      }

      final result = PermissionCheckResult(
        path: path,
        exists: true,
        canRead: canRead,
        canWrite: canWrite,
        canExecute: canExecute,
        isDirectory: isDir,
      );

      logger.info(
        'Permission check result for $path: read=$canRead, write=$canWrite, execute=$canExecute',
      );
      return result;
    } catch (e) {
      logger.warning('Permission check failed for $path: $e');
      return PermissionCheckResult(
        path: path,
        exists: false,
        canRead: false,
        canWrite: false,
        canExecute: false,
        isDirectory: false,
        error: e.toString(),
      );
    }
  }

  /// Cross-platform file writing with permission awareness
  static Future<void> writeFileWithPermissionsCrossPlatform(
    String path,
    String content, {
    FileSystem? fileSystem,
    bool recursive = false,
    PrivilegeEscalation? privilegeEscalation,
    bool requireElevation = false,
  }) async {
    logger.info(
      'Writing file with permission awareness (cross-platform): $path',
    );

    try {
      // Create parent directory if needed
      final dir = p.dirname(path);
      final dirExists = await directoryExists(dir, fileSystem: fileSystem);

      if (!dirExists && recursive) {
        await createDirectoryWithPermissionsCrossPlatform(
          dir,
          fileSystem: fileSystem,
          privilegeEscalation: privilegeEscalation,
          requireElevation: requireElevation,
        );
      }

      // Try direct write first
      if (!requireElevation) {
        try {
          await writeFile(
            path,
            content,
            fileSystem: fileSystem,
            recursive: false,
          );
          logger.info('File written successfully: $path');
          return;
        } catch (e) {
          if (_isPermissionException(e)) {
            logger.warning(
              'Permission denied for direct write, trying with privilege escalation: $path',
            );
            requireElevation = true;
          } else {
            rethrow;
          }
        }
      }

      // Try with privilege escalation if needed
      if (requireElevation && privilegeEscalation != null) {
        try {
          if (isUnixLike) {
            // Unix-specific privilege escalation
            final tempFile = (fileSystem ?? fs).systemTempDirectory
                .createTempSync()
                .childFile(
                  'configr_temp_${DateTime.now().millisecondsSinceEpoch}',
                );
            tempFile.writeAsStringSync(content);

            await privilegeEscalation.runWithElevatedPrivileges('cp', [
              tempFile.path,
              path,
            ]);
            await privilegeEscalation.runWithElevatedPrivileges('chmod', [
              '644',
              path,
            ]);

            tempFile.deleteSync();
          } else if (isWindows) {
            // Windows-specific privilege escalation
            final tempFile = (fileSystem ?? fs).systemTempDirectory
                .createTempSync()
                .childFile(
                  'configr_temp_${DateTime.now().millisecondsSinceEpoch}',
                );
            tempFile.writeAsStringSync(content);

            await privilegeEscalation.runWithElevatedPrivileges('copy', [
              tempFile.path,
              path,
            ]);

            tempFile.deleteSync();
          } else {
            // Fallback: direct write
            await writeFile(
              path,
              content,
              fileSystem: fileSystem,
              recursive: false,
            );
          }

          logger.info(
            'File written successfully with privilege escalation: $path',
          );
        } catch (e) {
          logger.error(
            'Failed to write file with privilege escalation: $path - $e',
          );
          throw Exception('Failed to write file with privilege escalation: $e');
        }
      } else {
        throw Exception(
          'Permission denied and no privilege escalation available for: $path',
        );
      }
    } catch (e) {
      logger.error('Failed to write file: $path - $e');
      rethrow;
    }
  }

  /// Cross-platform directory creation with permission awareness
  static Future<void> createDirectoryWithPermissionsCrossPlatform(
    String path, {
    FileSystem? fileSystem,
    bool recursive = true,
    PrivilegeEscalation? privilegeEscalation,
    bool requireElevation = false,
  }) async {
    logger.info(
      'Creating directory with permission awareness (cross-platform): $path',
    );

    // Check if directory already exists
    final dirExists = await directoryExists(path, fileSystem: fileSystem);
    if (dirExists) {
      logger.info('Directory already exists: $path');
      return;
    }

    try {
      // Try direct creation first
      if (!requireElevation) {
        try {
          await createDirectory(
            path,
            fileSystem: fileSystem,
            recursive: recursive,
          );
          logger.info('Directory created successfully: $path');
          return;
        } catch (e) {
          if (_isPermissionException(e)) {
            logger.warning(
              'Permission denied for direct creation, trying with privilege escalation: $path',
            );
            requireElevation = true;
          } else {
            rethrow;
          }
        }
      }

      // Try with privilege escalation if needed
      if (requireElevation && privilegeEscalation != null) {
        try {
          if (isUnixLike) {
            // Unix-specific directory creation
            final args = recursive ? ['-p', path] : [path];
            await privilegeEscalation.runWithElevatedPrivileges('mkdir', args);
          } else if (isWindows) {
            // Windows-specific directory creation
            final args = recursive ? ['/s', path] : [path];
            await privilegeEscalation.runWithElevatedPrivileges('mkdir', args);
          } else {
            // Fallback: direct creation
            await createDirectory(
              path,
              fileSystem: fileSystem,
              recursive: recursive,
            );
          }

          logger.info(
            'Directory created successfully with privilege escalation: $path',
          );
        } catch (e) {
          logger.error(
            'Failed to create directory with privilege escalation: $path - $e',
          );
          throw Exception(
            'Failed to create directory with privilege escalation: $e',
          );
        }
      } else {
        throw Exception(
          'Permission denied and no privilege escalation available for: $path',
        );
      }
    } catch (e) {
      logger.error('Failed to create directory: $path - $e');
      rethrow;
    }
  }

  /// Cross-platform file deletion with permission awareness
  static Future<void> deleteFileWithPermissionsCrossPlatform(
    String path, {
    FileSystem? fileSystem,
    PrivilegeEscalation? privilegeEscalation,
    bool requireElevation = false,
  }) async {
    logger.info(
      'Deleting file with permission awareness (cross-platform): $path',
    );

    // Check if file exists
    final fileExistsCheck = await fileExists(path, fileSystem: fileSystem);
    if (!fileExistsCheck) {
      logger.info('File does not exist: $path');
      return;
    }

    try {
      // Try direct deletion first
      if (!requireElevation) {
        try {
          await deleteFile(path, fileSystem: fileSystem);
          logger.info('File deleted successfully: $path');
          return;
        } catch (e) {
          if (_isPermissionException(e)) {
            logger.warning(
              'Permission denied for direct deletion, trying with privilege escalation: $path',
            );
            requireElevation = true;
          } else {
            rethrow;
          }
        }
      }

      // Try with privilege escalation if needed
      if (requireElevation && privilegeEscalation != null) {
        try {
          if (isUnixLike) {
            // Unix-specific file deletion
            await privilegeEscalation.runWithElevatedPrivileges('rm', [path]);
          } else if (isWindows) {
            // Windows-specific file deletion
            await privilegeEscalation.runWithElevatedPrivileges('del', [
              '/f',
              path,
            ]);
          } else {
            // Fallback: direct deletion
            await deleteFile(path, fileSystem: fileSystem);
          }

          logger.info(
            'File deleted successfully with privilege escalation: $path',
          );
        } catch (e) {
          logger.error(
            'Failed to delete file with privilege escalation: $path - $e',
          );
          throw Exception(
            'Failed to delete file with privilege escalation: $e',
          );
        }
      } else {
        throw Exception(
          'Permission denied and no privilege escalation available for: $path',
        );
      }
    } catch (e) {
      logger.error('Failed to delete file: $path - $e');
      rethrow;
    }
  }

  /// Cross-platform command execution with permission awareness
  static Future<ProcessResult> executeCommandWithPermissionsCrossPlatform(
    String command,
    List<String> arguments, {
    bool requireElevation = false,
    PrivilegeEscalation? privilegeEscalation,
    String? workingDirectory,
    Map<String, String>? environment,
    String? description,
  }) async {
    final cmdDesc = description ?? '$command ${arguments.join(' ')}';
    logger.info(
      'Executing command with permission awareness (cross-platform): $cmdDesc',
    );

    try {
      // First, try direct execution
      if (!requireElevation) {
        try {
          final result = await Process.run(
            command,
            arguments,
            workingDirectory: workingDirectory,
            environment: environment,
          );

          if (result.exitCode == 0) {
            logger.info('Command executed successfully: $cmdDesc');
            return result;
          }

          // Check if it's a permission error
          if (_isPermissionError(result)) {
            logger.warning(
              'Permission denied for command: $cmdDesc, trying with privilege escalation',
            );
            requireElevation = true;
          } else {
            logger.warning(
              'Command failed with exit code ${result.exitCode}: $cmdDesc',
            );
            return result;
          }
        } catch (e) {
          if (_isPermissionException(e)) {
            logger.warning(
              'Permission exception for command: $cmdDesc, trying with privilege escalation',
            );
            requireElevation = true;
          } else {
            rethrow;
          }
        }
      }

      // Try with privilege escalation if needed
      if (requireElevation && privilegeEscalation != null) {
        try {
          final result = await privilegeEscalation.runWithElevatedPrivileges(
            command,
            arguments,
          );

          if (result.exitCode == 0) {
            logger.info(
              'Command executed successfully with privilege escalation: $cmdDesc',
            );
            return result;
          } else {
            logger.error(
              'Command failed with privilege escalation (exit code ${result.exitCode}): $cmdDesc',
            );
            throw Exception(
              'Command failed with privilege escalation: $cmdDesc\n'
              'Exit code: ${result.exitCode}\n'
              'Stderr: ${result.stderr}',
            );
          }
        } catch (e) {
          logger.error('Privilege escalation failed for command: $cmdDesc');
          throw Exception(
            'Failed to execute command with privilege escalation: $cmdDesc\n'
            'Error: $e',
          );
        }
      }

      throw Exception('Unexpected execution path for command: $cmdDesc');
    } catch (e) {
      logger.error('Command execution failed: $cmdDesc - $e');
      rethrow;
    }
  }
}

/// Result of a permission check operation
class PermissionCheckResult {
  final String path;
  final bool exists;
  final bool canRead;
  final bool canWrite;
  final bool canExecute;
  final bool isDirectory;
  final String? error;

  PermissionCheckResult({
    required this.path,
    required this.exists,
    required this.canRead,
    required this.canWrite,
    required this.canExecute,
    required this.isDirectory,
    this.error,
  });

  /// Check if all required permissions are available
  bool hasPermissions({
    bool requireRead = false,
    bool requireWrite = false,
    bool requireExecute = false,
  }) {
    if (requireRead && !canRead) return false;
    if (requireWrite && !canWrite) return false;
    if (requireExecute && !canExecute) return false;
    return true;
  }

  @override
  String toString() {
    return 'PermissionCheckResult(path: $path, exists: $exists, '
        'read: $canRead, write: $canWrite, execute: $canExecute, '
        'isDirectory: $isDirectory${error != null ? ', error: $error' : ''})';
  }
}
