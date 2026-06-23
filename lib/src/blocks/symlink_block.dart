import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/file_utils.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:file/file.dart' show File;
import 'package:glob/glob.dart';
import 'package:i3config/i3config_v2.dart' as i3;
import 'package:path/path.dart' as path;

/// Block handler for the `symlink` config action.
///
/// Creates symbolic links from source to destination with pattern support
/// for bulk operations, conflict resolution, and full rollback.
///
/// ```i3
/// symlink {
///   source = "/path/to/target"
///   destination = "/path/to/link"
///   conflict_resolution = "overwrite"   # overwrite | skip | error
///   create_directories = true
///   validate_targets = true
/// }
/// ```
class SymlinkBlock extends ActionBlock {
  @override
  String get blockType => 'symlink';

  // ---------------------------------------------------------------------------
  // Symlink-specific properties
  // ---------------------------------------------------------------------------

  List<String> includePatterns = [];
  List<String> excludePatterns = [];
  String conflictResolution = 'error';
  bool createDirectories = true;
  bool validateTargets = true;
  bool showProgress = true;

  // ---------------------------------------------------------------------------
  // Execution state
  // ---------------------------------------------------------------------------

  bool hadToCreateDstDir = false;
  bool symlinkExisted = false;
  String? originalTarget;
  bool sourceExists = false;
  int createdSymlinks = 0;
  int skippedSymlinks = 0;
  int overwrittenSymlinks = 0;
  int failedSymlinks = 0;
  List<String> createdPaths = [];
  List<String> skippedPaths = [];
  List<String> failedPaths = [];

  SymlinkBlock();

  // ---------------------------------------------------------------------------
  // Handler pipeline
  // ---------------------------------------------------------------------------

  @override
  Map<String, String> get additionalProperties => {
    if (includePatterns.isNotEmpty) 'include': includePatterns.join(', '),
    if (excludePatterns.isNotEmpty) 'exclude': excludePatterns.join(', '),
    if (conflictResolution != 'error')
      'conflict_resolution': conflictResolution,
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (!createDirectories) 'create_directories': createDirectories,
    if (!validateTargets) 'validate_targets': validateTargets,
    if (!showProgress) 'show_progress': showProgress,
  };

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);

    final include = context.getVariable('include');
    if (include is String) {
      includePatterns = include.split(',').map((s) => s.trim()).toList();
    } else if (include is List) {
      includePatterns = include.cast<String>();
    }

    final exclude = context.getVariable('exclude');
    if (exclude is String) {
      excludePatterns = exclude.split(',').map((s) => s.trim()).toList();
    } else if (exclude is List) {
      excludePatterns = exclude.cast<String>();
    }

    final crVal = context.getVariable('conflict_resolution');
    if (crVal is String) conflictResolution = crVal;

    createDirectories = switch (context.getVariable('create_directories')) {
      false || 'false' => false,
      _ => true,
    };

    validateTargets = switch (context.getVariable('validate_targets')) {
      false || 'false' => false,
      _ => true,
    };

    showProgress = switch (context.getVariable('show_progress')) {
      false || 'false' => false,
      _ => true,
    };
  }

  // ---------------------------------------------------------------------------
  // Execution
  // ---------------------------------------------------------------------------

  @override
  Future<void> execute() async {
    emitEvent(
      StartedEvent(
        moduleId: id,
        message: 'Creating symlinks from $source → $destination',
      ),
    );

    try {
      // Determine if bulk operation
      if (includePatterns.isNotEmpty || await _isDirectoryOperation()) {
        await _executeBulkOperation();
      } else {
        await _executeSingleOperation();
      }

      emitEvent(
        CompletedEvent(
          moduleId: id,
          message:
              'Symlink operation completed — $createdSymlinks created, '
              '$skippedSymlinks skipped, $overwrittenSymlinks overwritten, '
              '$failedSymlinks failed',
        ),
      );
    } catch (e, _) {
      emitEvent(
        FailedEvent(moduleId: id, message: 'Symlink operation failed: $e'),
      );
      throw ActionFailedException(
        'Failed to create symlinks $source → $destination',
        cause: e,
        moduleId: id,
      );
    }

    status = 'completed';
  }

  @override
  Future<void> rollback() async {
    emitEvent(
      StartedEvent(moduleId: id, message: 'Rolling back symlink creation'),
    );

    try {
      // Remove created symlinks
      for (final createdPath in createdPaths) {
        if (await FileUtils.isSymlink(createdPath, fileSystem: fileSystem)) {
          logger.info('Deleting symlink $createdPath');
          await FileUtils.deleteFile(createdPath, fileSystem: fileSystem);
        }
      }

      // Restore original symlink if it existed
      if (symlinkExisted && originalTarget != null) {
        if (await FileUtils.isSymlink(destination, fileSystem: fileSystem)) {
          await FileUtils.deleteFile(destination, fileSystem: fileSystem);
        }
        await FileUtils.createSymlink(
          originalTarget!,
          destination,
          fileSystem: fileSystem,
        );
      }

      // Clean up created directories
      if (hadToCreateDstDir) {
        final symlinkDir = path.dirname(destination);
        if (await FileUtils.directoryExists(
          symlinkDir,
          fileSystem: fileSystem,
        )) {
          await FileUtils.deleteDirectory(
            symlinkDir,
            recursive: true,
            fileSystem: fileSystem,
          );
        }
      }

      // Clean up directories created for bulk operations
      final createdDirs = <String>{};
      for (final createdPath in createdPaths) {
        final dir = path.dirname(createdPath);
        if (dir != destination) createdDirs.add(dir);
      }
      for (final dir in createdDirs) {
        if (await FileUtils.directoryExists(dir, fileSystem: fileSystem)) {
          final dirEntity = fileSystem.directory(dir);
          final isEmpty = await dirEntity.list().isEmpty;
          if (isEmpty) {
            await FileUtils.deleteDirectory(
              dir,
              recursive: false,
              fileSystem: fileSystem,
            );
          }
        }
      }

      for (final child in children) {
        await child.rollback();
      }

      emitEvent(
        CompletedEvent(moduleId: id, message: 'Symlink rollback completed'),
      );
    } catch (e, _) {
      emitEvent(
        FailedEvent(moduleId: id, message: 'Symlink rollback failed: $e'),
      );
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<bool> _isDirectoryOperation() async {
    final existCheck = await FileUtils.pathExists(
      source,
      fileSystem: fileSystem,
    );
    return existCheck.isDir;
  }

  Future<void> _executeSingleOperation() async {
    final symlinkDir = path.dirname(destination);

    // Validate source exists
    if (validateTargets) {
      final exists = await FileUtils.fileExists(source, fileSystem: fileSystem);
      sourceExists = exists;
      if (!exists) {
        throw SourceNotFoundException(source);
      }
    }

    // Create destination directory if needed
    if (createDirectories &&
        !await FileUtils.directoryExists(symlinkDir, fileSystem: fileSystem)) {
      logger.info('Creating directory $symlinkDir');
      await FileUtils.createDirectory(symlinkDir, fileSystem: fileSystem);
      hadToCreateDstDir = true;
    }

    // Handle existing symlink
    if (await FileUtils.isSymlink(destination, fileSystem: fileSystem)) {
      originalTarget = await FileUtils.readSymlink(
        destination,
        fileSystem: fileSystem,
      );
      symlinkExisted = true;

      switch (conflictResolution) {
        case 'overwrite':
          logger.info('Overwriting existing symlink $destination');
          await FileUtils.deleteFile(destination, fileSystem: fileSystem);
          await FileUtils.createSymlink(
            source,
            destination,
            fileSystem: fileSystem,
          );
          overwrittenSymlinks++;
          createdPaths.add(destination);
          break;
        case 'skip':
          logger.info('Skipping existing symlink $destination');
          skippedSymlinks++;
          skippedPaths.add(destination);
          break;
        case 'error':
          throw ActionFailedException(
            'Symlink already exists: $destination',
            moduleId: id,
          );
      }
    } else {
      logger.info('Creating symlink from $source to $destination');
      await FileUtils.createSymlink(
        source,
        destination,
        fileSystem: fileSystem,
      );
      createdSymlinks++;
      createdPaths.add(destination);
    }
  }

  Future<void> _executeBulkOperation() async {
    final filesToProcess = await _getFilesToProcess(source);

    emitEvent(
      ProgressEvent(
        moduleId: id,
        current: 0,
        total: filesToProcess.length,
        message: 'Processing symlinks...',
      ),
    );

    for (var i = 0; i < filesToProcess.length; i++) {
      final filePath = filesToProcess[i];
      try {
        await _processSingleFile(filePath, source);

        if (showProgress && (i + 1) % 10 == 0) {
          emitEvent(
            ProgressEvent(
              moduleId: id,
              current: i + 1,
              total: filesToProcess.length,
              message: 'Linking files...',
            ),
          );
        }
      } catch (e) {
        logger.severe('Failed to process file $filePath: $e');
        failedSymlinks++;
        failedPaths.add(filePath);
      }
    }
  }

  Future<void> _processSingleFile(String filePath, String sourceBase) async {
    final relativePath = path.relative(filePath, from: sourceBase);
    final targetPath = path.join(destination, relativePath);
    final targetDir = path.dirname(targetPath);

    // Create target directory if needed
    if (createDirectories &&
        !await FileUtils.directoryExists(targetDir, fileSystem: fileSystem)) {
      await FileUtils.createDirectory(targetDir, fileSystem: fileSystem);
    }

    // Handle existing symlink
    if (await FileUtils.isSymlink(targetPath, fileSystem: fileSystem)) {
      switch (conflictResolution) {
        case 'overwrite':
          await FileUtils.deleteFile(targetPath, fileSystem: fileSystem);
          await FileUtils.createSymlink(
            filePath,
            targetPath,
            fileSystem: fileSystem,
          );
          overwrittenSymlinks++;
          createdPaths.add(targetPath);
          break;
        case 'skip':
          skippedSymlinks++;
          skippedPaths.add(targetPath);
          break;
        case 'error':
          throw ActionFailedException(
            'Symlink already exists: $targetPath',
            moduleId: id,
          );
      }
    } else {
      await FileUtils.createSymlink(
        filePath,
        targetPath,
        fileSystem: fileSystem,
      );
      createdSymlinks++;
      createdPaths.add(targetPath);
    }
  }

  Future<List<String>> _getFilesToProcess(String sourcePath) async {
    final files = <String>[];

    if (includePatterns.isEmpty) {
      if (await FileUtils.directoryExists(sourcePath, fileSystem: fileSystem)) {
        await _collectFilesRecursively(sourcePath, files);
      } else if (await FileUtils.fileExists(
        sourcePath,
        fileSystem: fileSystem,
      )) {
        files.add(sourcePath);
      }
    } else {
      if (await FileUtils.directoryExists(sourcePath, fileSystem: fileSystem)) {
        await _collectFilesRecursively(sourcePath, files);
      }

      // Filter files by include patterns
      files.removeWhere((file) {
        return !includePatterns.any((pattern) {
          try {
            return Glob(pattern).matches(file);
          } catch (_) {
            return file == pattern;
          }
        });
      });
    }

    // Apply exclude patterns
    if (excludePatterns.isNotEmpty) {
      files.removeWhere((file) {
        return excludePatterns.any((pattern) {
          try {
            return Glob(pattern).matches(file);
          } catch (_) {
            return file.contains(pattern);
          }
        });
      });
    }

    return files;
  }

  Future<void> _collectFilesRecursively(
    String dirPath,
    List<String> files,
  ) async {
    if (!await FileUtils.directoryExists(dirPath, fileSystem: fileSystem)) {
      return;
    }

    final dir = fileSystem.directory(dirPath);
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        files.add(entity.path);
      }
    }
  }
}
