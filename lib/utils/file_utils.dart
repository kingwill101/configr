import 'dart:async';
import 'dart:io' as io;
import 'dart:io';

import 'package:configr/utils/privellage_escallation.dart';
import 'package:configr/utils/fs.dart';
import 'package:configr/utils/logging.dart';
import 'package:crypto/crypto.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as p;

/// Utility class containing file system related helper methods
class FileUtils {
  /// Copies a file from source path to destination path
  /// Returns the copied File
  static Future<File> copyFile(String source, String destination,
      {FileSystem? fileSystem}) async {
    Completer<File> completer = Completer();
    logger.info('Copying file from $source to $destination');
    (fileSystem ?? fs).file(source).copy(destination).then((f) {
      logger.info('File copied successfully');
      completer.complete(f);
    }).catchError((err, stacktrace) {
      logger.severe('File not copied successfully', err, stacktrace);
      completer.completeError(err, stacktrace);
    });

    return completer.future;
  }

  /// Checks if a directory exists at the given path
  /// Returns true if directory exists, false otherwise
  static Future<bool> directoryExists(String path,
      {FileSystem? fileSystem}) async {
    Completer<bool> completer = Completer();
    (fileSystem ?? fs).directory(path).exists().then((exists) {
      completer.complete(exists);
    }).catchError((err, stacktrace) {
      completer.completeError(err, stacktrace);
    });
    return completer.future;
  }

  /// Checks if a file exists at the given path
  /// Returns true if file exists, false otherwise
  static Future<bool> fileExists(String path, {FileSystem? fileSystem}) async {
    Completer<bool> completer = Completer();
    final file = (fileSystem ?? fs).file(path);
    file.exists().then((exists) {
      completer.complete(exists);
    }).catchError((err, stacktrace) {
      completer.completeError(err, stacktrace);
    });
    return completer.future;
  }

  /// Checks if a path exists and whether it's a directory
  /// Returns tuple of (exists, isDirectory)
  static Future<(bool exists, bool isDir)> pathExists(String path,
      {FileSystem? fileSystem}) async {
    Completer<(bool, bool)> completer = Completer();

    fileExists(path, fileSystem: fileSystem).then((exists) {
      if (exists) {
        completer.complete((true, false));
      } else {
        directoryExists(path, fileSystem: fileSystem).then((exists) {
          if (exists) {
            completer.complete((true, true));
          } else {
            completer.complete((false, false));
          }
        }).catchError((err, stacktrace) {
          completer.completeError(err, stacktrace);
        });
      }
    }).catchError((err, stacktrace) {
      completer.completeError(err, stacktrace);
    });

    return completer.future;
  }

  /// Deletes a file at the given path
  static Future deleteFile(String path, {FileSystem? fileSystem}) async {
    Completer<void> completer = Completer();
    final file = (fileSystem ?? fs).file(path);
    file.exists().then((exists) async {
      if (exists) {
        await file.delete();
        logger.info('File $path deleted');
      } else {
        logger.info('File $path does not exist');
      }
      completer.complete();
    }).catchError((err, stacktrace) {
      completer.completeError(err, stacktrace);
    });
    return completer.future;
  }

  /// Deletes a directory and optionally its contents recursively
  static Future<void> deleteDirectory(String path,
      {FileSystem? fileSystem, bool recursive = true}) async {
    Completer<void> completer = Completer();
    final directory = (fileSystem ?? fs).directory(path);
    directory.exists().then((exists) async {
      if (exists) {
        await directory.delete(recursive: recursive);
        logger.info('Directory $path deleted');
      } else {
        logger.info('Directory $path does not exist');
      }
      completer.complete();
    }).catchError((err, stacktrace) {
      completer.completeError(err, stacktrace);
    });
    return completer.future;
  }

  /// Creates a new directory at the given path
  /// Returns the created Directory
  static Future<io.Directory> createDirectory(String path,
      {FileSystem? fileSystem, bool recursive = true}) async {
    Completer<io.Directory> completer = Completer();
    final directory = (fileSystem ?? fs).directory(path);
    directory.exists().then((exists) async {
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
    }).catchError((err, stacktrace) {
      logger.severe('Failed to create directory $path', err, stacktrace);
      completer.completeError(err, stacktrace);
    });
    return completer.future;
  }

  /// Changes the owner of a file
  static Future<void> setOwner(String filePath, String owner,
      {FileSystem? fileSystem}) async {
    final result = await Process.run(
      'chown',
      [owner, filePath],
      runInShell: true,
    );
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
  static Future<void> createSymlink(String target, String link,
      {FileSystem? fileSystem}) async {
    Completer<void> completer = Completer();
    (fileSystem ?? fs).link(link).create(target).then((_) {
      completer.complete();
    }).catchError((err, stacktrace) {
      completer.completeError(err, stacktrace);
    });
    return completer.future;
  }

  /// Computes SHA-256 hash of a file's contents
  static Future<String> computeFileHash(String filePath,
      {FileSystem? fileSystem}) async {
    Completer<String> completer = Completer();
    final file = (fileSystem ?? fs).file(filePath);
    file.readAsBytes().then((contents) {
      completer.complete(sha256.convert(contents).toString());
    }).catchError((err, stacktrace) {
      completer.completeError(err, stacktrace);
    });
    return completer.future;
  }

  /// Moves a file from source to destination path
  static moveFile(String source, destinationPath,
      {FileSystem? fileSystem}) async {
    Completer<void> completer = Completer();
    final sourceFile = (fileSystem ?? fs).file(source);
    sourceFile.exists().then((exists) async {
      if (exists) {
        await sourceFile.copy(destinationPath);
        await sourceFile.delete();
        logger.info('File $source moved to $destinationPath');
      } else {
        logger.warning('File $source does not exist');
      }
      completer.complete();
    }).catchError((err, stacktrace) {
      completer.completeError(err, stacktrace);
    });
    return completer.future;
  }

  /// Changes the ownership of a file and returns the original ownership
  /// Can use elevated privileges if provided
  static Future<Map<String, String>> chown(
      String destinationPath, String? owner, String? group,
      {FileSystem? fileSystem,
      PrivilegeEscalation? privilegeEscalation}) async {
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
          ? await privilegeEscalation
              .runWithElevatedPrivileges('chown', [chownArg, destinationPath])
          : await Process.run(
              'chown',
              [chownArg, destinationPath],
              runInShell: true,
            );

      if (result.exitCode != 0) {
        throw ProcessException(
          'chown',
          [chownArg, destinationPath],
          result.stderr.toString(),
          result.exitCode,
        );
      }
    } catch (e) {
      print('Failed to change ownership of $destinationPath: $e');
      rethrow;
    }

    logger.info('Ownership changed for $destinationPath');
    return currentOwnership;
  }

  /// Changes file permissions and returns original permissions
  /// Can use elevated privileges if provided
  static Future<String> chmod(String destinationPath, String mode,
      {FileSystem? fileSystem,
      PrivilegeEscalation? privilegeEscalation}) async {
    // Get current permissions before changing them
    final currentPermissions = await getPermissions(destinationPath);

    // Run the chmod command
    try {
      final result = privilegeEscalation != null
          ? await privilegeEscalation
              .runWithElevatedPrivileges('chmod', [mode, destinationPath])
          : await Process.run(
              'chmod',
              [mode, destinationPath],
              runInShell: true,
            );

      if (result.exitCode != 0) {
        throw ProcessException(
          'chmod',
          [mode, destinationPath],
          result.stderr.toString(),
          result.exitCode,
        );
      }

      print('Permissions of $destinationPath changed to $mode');
    } catch (e) {
      print('Failed to change permissions of $destinationPath: $e');
      rethrow;
    }

    // Return the current permissions for rollback purposes
    return currentPermissions;
  }

  /// Gets current owner and group of a file
  static Future<Map<String, String>> getOwnership(
      String destinationPath) async {
    try {
      // Use stat to get ownership details
      // %U = owner name, %G = group name
      final result = await Process.run('stat', ['-c', '%U %G', destinationPath],
          runInShell: true);

      if (result.exitCode != 0) {
        throw ProcessException('stat', ['-c', '%U %G', destinationPath],
            result.stderr.toString(), result.exitCode);
      }

      final parts = result.stdout.trim().split(' ');
      if (parts.length != 2) {
        throw FormatException(
            'Unexpected stat output format: ${result.stdout}');
      }

      return {
        'owner': parts[0],
        'group': parts[1],
      };
    } catch (e) {
      logger.severe('Failed to retrieve ownership for $destinationPath: $e');
      rethrow;
    }
  }

  /// Gets current permissions of a file in octal format
  static Future<String> getPermissions(String destinationPath) async {
    try {
      // Run `stat` to get the permissions in numeric format
      final result = await Process.run('stat', ['-c', '%a', destinationPath],
          runInShell: true);

      if (result.exitCode != 0) {
        throw ProcessException('stat', ['-c', '%a', destinationPath],
            result.stderr.toString(), result.exitCode);
      }

      // Return the permissions as a string
      return result.stdout.trim();
    } catch (e) {
      print('Failed to retrieve permissions for $destinationPath: $e');
      rethrow;
    }
  }

  /// Checks if a path is a symbolic link
  static Future<bool> isSymlink(symlinkPath, {FileSystem? fileSystem}) async {
    return await (fileSystem ?? fs).isLink(symlinkPath);
  }

  /// Gets the target path that a symbolic link points to
  static Future<String?> readSymlink(String symlinkPath,
      {FileSystem? fileSystem}) async {
    try {
      final link = (fileSystem ?? fs).link(symlinkPath);

      // Check if the provided path is actually a symlink
      if (!await link.exists()) {
        throw FileSystemException(
            'The specified path is not a valid symlink', symlinkPath);
      }

      // Resolve the symlink target
      final targetPath = await link.target();
      print('Symlink $symlinkPath points to $targetPath');

      return targetPath;
    } catch (e) {
      print('Failed to read symlink $symlinkPath: $e');
      return null;
    }
  }

  /// Recursively copies a directory and its contents
  static Future<Directory> copyDir(String source, String destination,
      {FileSystem? fileSystem, bool recursive = false}) async {
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
        await copyDir(newDir, entity.path,
            fileSystem: fileSystem, recursive: recursive);
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

  /// Writes string content to a file, creating parent directories if needed
  static Future<void> writeFile(String path, String content,
      {FileSystem? fileSystem, bool recursive = false}) async {
    final fsToUse = fileSystem ?? fs;
    final dir = p.dirname(path);
    final dirExists = await directoryExists(dir, fileSystem: fileSystem);

    if (!dirExists && recursive) {
      logger.info("creating destination dir $dir");
      await createDirectory(dir, fileSystem: fileSystem);
    }
    await fsToUse.file(path).writeAsString(content);
  }
}
