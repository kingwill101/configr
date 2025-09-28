import 'dart:io';
import 'package:configr/events/module_events.dart';
import 'package:configr/exceptions.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/file_utils.dart';
import 'package:configr/utils/logging.dart';
import 'package:configr/utils/event_bus.dart';
import 'package:path/path.dart' as path;
import 'package:glob/glob.dart';

/// Enhanced file symlink module with bulk operations, validation, and progress tracking.
/// 
/// Features:
/// - Bulk symlink operations using glob patterns
/// - Comprehensive validation of source and target paths
/// - Progress tracking for bulk operations
/// - Multiple conflict resolution strategies
/// - Comprehensive event emission
/// - Rollback support
class FileSymlinkModule extends ResourceModule {
  // State getters
  bool get hadToCreateDstDir => state['hadToCreateDstDir'] as bool? ?? false;
  bool get symlinkExisted => state['symlinkExisted'] as bool? ?? false;
  String? get originalTarget => state['originalTarget'] as String?;
  bool get sourceExists => state['sourceExists'] as bool? ?? false;
  
  // Enhanced features
  List<String> get includePatterns => (state['includePatterns'] as List<dynamic>?)?.cast<String>() ?? [];
  List<String> get excludePatterns => (state['excludePatterns'] as List<dynamic>?)?.cast<String>() ?? [];
  String get conflictResolution => state['conflictResolution'] as String? ?? 'skip';
  bool get showProgress => state['showProgress'] as bool? ?? true;
  bool get validateTargets => state['validateTargets'] as bool? ?? true;
  bool get createDirectories => state['createDirectories'] as bool? ?? true;
  int get createdSymlinks => state['createdSymlinks'] as int? ?? 0;
  int get totalSymlinks => state['totalSymlinks'] as int? ?? 0;
  int get skippedSymlinks => state['skippedSymlinks'] as int? ?? 0;
  int get overwrittenSymlinks => state['overwrittenSymlinks'] as int? ?? 0;
  int get failedSymlinks => state['failedSymlinks'] as int? ?? 0;
  List<String> get createdPaths => (state['createdPaths'] as List<dynamic>?)?.cast<String>() ?? [];
  List<String> get skippedPaths => (state['skippedPaths'] as List<dynamic>?)?.cast<String>() ?? [];
  List<String> get failedPaths => (state['failedPaths'] as List<dynamic>?)?.cast<String>() ?? [];
  bool get rollbackCompleted => state['rollbackCompleted'] as bool? ?? false;

  FileSymlinkModule(super.file, super.action,
      {super.allowedActions = const ['symlink'], super.fileSystem}) {
    updateState({
      'hadToCreateDstDir': false,
      'symlinkExisted': false,
      'originalTarget': null,
      'sourceExists': false,
      'includePatterns': [],
      'excludePatterns': [],
      'conflictResolution': 'skip',
      'showProgress': true,
      'validateTargets': true,
      'createDirectories': true,
      'createdSymlinks': 0,
      'totalSymlinks': 0,
      'skippedSymlinks': 0,
      'overwrittenSymlinks': 0,
      'failedSymlinks': 0,
      'createdPaths': [],
      'skippedPaths': [],
      'failedPaths': []
    });
  }

  @override
  Future<void> execute() async {
    emitEvent(StartedEvent(moduleId: action.id, message: 'Creating symlinks'));
    
    // Parse configuration from action properties
    _parseConfiguration();
    
    // Execute child modules first
    executeModules();
    if (isRollingBack) {
      return;
    }

    try {
      // Determine if this is a bulk operation or single symlink
      if (includePatterns.isNotEmpty || await _isDirectoryOperation()) {
        await _executeBulkOperation();
      } else {
        await _executeSingleOperation();
      }
    } catch (e, st) {
      updateState({
        'error': e.toString(),
        'stackTrace': st.toString()
      });
      throw SymlinkCreationException(destination, moduleId: action.id, cause: e);
    }

    emitEvent(CompletedEvent(moduleId: action.id, message: 'Symlink operation completed successfully'));
    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
    await saveState();
  }

  /// Parse configuration from action properties
  void _parseConfiguration() {
    final properties = action.properties;
    
    if (properties.containsKey('include_patterns')) {
      final patterns = properties['include_patterns'];
      if (patterns is List) {
        updateState({'includePatterns': patterns.cast<String>()});
      }
    }
    
    if (properties.containsKey('exclude_patterns')) {
      final patterns = properties['exclude_patterns'];
      if (patterns is List) {
        updateState({'excludePatterns': patterns.cast<String>()});
      }
    }
    
    if (properties.containsKey('conflict_resolution')) {
      updateState({'conflictResolution': properties['conflict_resolution']});
    }
    
    if (properties.containsKey('show_progress')) {
      updateState({'showProgress': properties['show_progress']});
    }
    
    if (properties.containsKey('validate_targets')) {
      updateState({'validateTargets': properties['validate_targets']});
    }
    
    if (properties.containsKey('create_directories')) {
      updateState({'createDirectories': properties['create_directories']});
    }
  }

  /// Check if this is a directory operation
  Future<bool> _isDirectoryOperation() async {
    final sourcePath = path.absolute(source);
    return file.type == 'directory' || 
           (await FileUtils.pathExists(sourcePath, fileSystem: fileSystem)).isDir;
  }

  /// Execute single symlink operation
  Future<void> _executeSingleOperation() async {
    final sourcePath = path.absolute(source);
    final symlinkDir = path.dirname(destination);

    emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Source path: $sourcePath'));
    emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Target path: $destination'));

    // Validate source exists
    if (validateTargets) {
      final exists = await FileUtils.pathExists(sourcePath, fileSystem: fileSystem);
      updateState({'sourceExists': exists.exists});

      if (!exists.exists) {
        throw SourceNotFoundException(sourcePath);
      }
    }

    // Create destination directory if needed
    if (createDirectories && !await FileUtils.directoryExists(symlinkDir, fileSystem: fileSystem)) {
      logger.info('Creating directory $symlinkDir');
      await FileUtils.createDirectory(symlinkDir, fileSystem: fileSystem);
      updateState({'hadToCreateDstDir': true});
    }

    // Handle existing symlink
    if (await FileUtils.isSymlink(destination, fileSystem: fileSystem)) {
      final target = await FileUtils.readSymlink(destination, fileSystem: fileSystem);
      updateState({
        'symlinkExisted': true,
        'originalTarget': target
      });
      
      switch (conflictResolution) {
        case 'overwrite':
          logger.info('Overwriting existing symlink $destination');
          await FileUtils.deleteFile(destination, fileSystem: fileSystem);
          await FileUtils.createSymlink(sourcePath, destination, fileSystem: fileSystem);
          updateState({'overwrittenSymlinks': overwrittenSymlinks + 1});
          break;
        case 'skip':
          logger.info('Skipping existing symlink $destination');
          updateState({
            'skippedSymlinks': skippedSymlinks + 1,
            'skippedPaths': [...skippedPaths, destination]
          });
          break;
        case 'error':
          throw SymlinkCreationException(destination, moduleId: action.id, 
              cause: Exception('Symlink already exists: $destination'));
      }
    } else {
      logger.info('Creating symlink from $sourcePath to $destination');
      await FileUtils.createSymlink(sourcePath, destination, fileSystem: fileSystem);
      updateState({
        'createdSymlinks': createdSymlinks + 1,
        'createdPaths': [...createdPaths, destination]
      });
    }
  }

  /// Execute bulk symlink operation
  Future<void> _executeBulkOperation() async {
    final sourcePath = path.absolute(source);
    
    // Get all files to process
    final filesToProcess = await _getFilesToProcess(sourcePath);
    updateState({'totalSymlinks': filesToProcess.length});
    
    emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, 
        message: 'Processing ${filesToProcess.length} files for bulk symlink operation'));

    int processed = 0;
    for (final filePath in filesToProcess) {
      try {
        await _processSingleFile(filePath, sourcePath);
        processed++;
        
        if (showProgress && processed % 10 == 0) {
          emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, 
              message: 'Progress: $processed/${filesToProcess.length} files processed'));
        }
      } catch (e) {
        logger.severe('Failed to process file $filePath: $e');
        updateState({
          'failedSymlinks': failedSymlinks + 1,
          'failedPaths': [...failedPaths, filePath]
        });
      }
    }
    
    emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, 
        message: 'Bulk operation completed: ${createdSymlinks} created, ${skippedSymlinks} skipped, ${failedSymlinks} failed'));
  }

  /// Get list of files to process based on patterns
  Future<List<String>> _getFilesToProcess(String sourcePath) async {
    final files = <String>[];
    
    if (includePatterns.isEmpty) {
      // No patterns specified, process all files in source
      if (await FileUtils.directoryExists(sourcePath, fileSystem: fileSystem)) {
        await _collectFilesRecursively(sourcePath, files);
      } else if (await FileUtils.fileExists(sourcePath, fileSystem: fileSystem)) {
        files.add(sourcePath);
      } else {
        // If neither directory nor file exists, try to find files that match the source pattern
        // This handles cases where test helpers create individual files without creating the directory
        final sourceDir = path.dirname(sourcePath);
        if (await FileUtils.directoryExists(sourceDir, fileSystem: fileSystem)) {
          await _collectFilesRecursively(sourceDir, files);
          // Filter to only include files that start with the source path
          files.removeWhere((file) => !file.startsWith(sourcePath));
        }
      }
    } else {
      // Use include patterns - collect all files and filter by patterns
      if (await FileUtils.directoryExists(sourcePath, fileSystem: fileSystem)) {
        await _collectFilesRecursively(sourcePath, files);
      } else {
        // If directory doesn't exist, try to find files that match the source pattern
        final sourceDir = path.dirname(sourcePath);
        if (await FileUtils.directoryExists(sourceDir, fileSystem: fileSystem)) {
          await _collectFilesRecursively(sourceDir, files);
          // Filter to only include files that start with the source path
          files.removeWhere((file) => !file.startsWith(sourcePath));
        }
      }
      
      // Filter files by include patterns
      files.removeWhere((file) {
        return !includePatterns.any((pattern) {
          try {
            final glob = Glob(pattern);
            return glob.matches(file);
          } catch (e) {
            // If glob pattern is invalid, fall back to exact match
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
            final glob = Glob(pattern);
            return glob.matches(file);
          } catch (e) {
            // If glob pattern is invalid, fall back to exact match
            return file == pattern;
          }
        });
      });
    }
    
    return files;
  }

  /// Recursively collect files from directory
  Future<void> _collectFilesRecursively(String dirPath, List<String> files) async {
    if (!await FileUtils.directoryExists(dirPath, fileSystem: fileSystem)) {
      return;
    }
    
    final dir = Directory(dirPath);
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        files.add(entity.path);
      }
    }
  }

  /// Process a single file for symlink creation
  Future<void> _processSingleFile(String filePath, String sourceBase) async {
    // Calculate relative path from source base
    final relativePath = path.relative(filePath, from: sourceBase);
    final targetPath = path.join(destination, relativePath);
    final targetDir = path.dirname(targetPath);
    
    // Create target directory if needed
    if (createDirectories && !await FileUtils.directoryExists(targetDir, fileSystem: fileSystem)) {
      await FileUtils.createDirectory(targetDir, fileSystem: fileSystem);
    }
    
    // Handle existing symlink
    if (await FileUtils.isSymlink(targetPath, fileSystem: fileSystem)) {
      switch (conflictResolution) {
        case 'overwrite':
          await FileUtils.deleteFile(targetPath, fileSystem: fileSystem);
          await FileUtils.createSymlink(filePath, targetPath, fileSystem: fileSystem);
          updateState({
            'overwrittenSymlinks': overwrittenSymlinks + 1,
            'createdPaths': [...createdPaths, targetPath]
          });
          break;
        case 'skip':
          updateState({
            'skippedSymlinks': skippedSymlinks + 1,
            'skippedPaths': [...skippedPaths, targetPath]
          });
          break;
        case 'error':
          throw SymlinkCreationException(targetPath, moduleId: action.id, 
              cause: Exception('Symlink already exists: $targetPath'));
      }
    } else {
      await FileUtils.createSymlink(filePath, targetPath, fileSystem: fileSystem);
      updateState({
        'createdSymlinks': createdSymlinks + 1,
        'createdPaths': [...createdPaths, targetPath]
      });
    }
  }

  @override
  Future<void> rollback() async {
    emitEvent(StartedEvent(moduleId: action.id, message: 'Rolling back symlink creation'));
    emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Removing symlinks'));
    
    try {
      // Rollback created symlinks
      for (final createdPath in createdPaths) {
        if (await FileUtils.isSymlink(createdPath, fileSystem: fileSystem)) {
          logger.info('Deleting symlink $createdPath');
          await FileUtils.deleteFile(createdPath, fileSystem: fileSystem);
        }
      }

      // Restore original symlink if it existed
      if (symlinkExisted && originalTarget != null) {
        logger.info('Restoring original symlink $destination to point to $originalTarget');
        // Delete the current symlink first if it exists
        if (await FileUtils.isSymlink(destination, fileSystem: fileSystem)) {
          await FileUtils.deleteFile(destination, fileSystem: fileSystem);
        }
        await FileUtils.createSymlink(originalTarget!, destination, fileSystem: fileSystem);
      }

      // Clean up created directories
      if (hadToCreateDstDir) {
        final symlinkDir = path.dirname(destination);
        if (await FileUtils.directoryExists(symlinkDir, fileSystem: fileSystem)) {
          logger.info('Deleting created directory $symlinkDir');
          await FileUtils.deleteDirectory(symlinkDir, recursive: true, fileSystem: fileSystem);
        }
      }
      
      // Clean up directories created for bulk operations
      final createdDirs = <String>{};
      for (final createdPath in createdPaths) {
        final dir = path.dirname(createdPath);
        if (dir != destination && !createdDirs.contains(dir)) {
          createdDirs.add(dir);
        }
      }
      
      for (final dir in createdDirs) {
        if (await FileUtils.directoryExists(dir, fileSystem: fileSystem)) {
          // Check if directory is empty
          final dirEntity = Directory(dir);
          final isEmpty = await dirEntity.list().isEmpty;
          if (isEmpty) {
            logger.info('Deleting empty directory $dir');
            await FileUtils.deleteDirectory(dir, recursive: false, fileSystem: fileSystem);
          }
        }
      }
      
      updateState({'rollbackCompleted': true});
    } catch (e, st) {
      updateState({
        'rollbackError': e.toString(),
        'rollbackStackTrace': st.toString()
      });
      rethrow;
    }

    for (var module in childModules) {
      await module.rollback();
    }
    
    emitEvent(CompletedEvent(moduleId: action.id, message: 'Rollback completed'));
    await saveState();
  }
}