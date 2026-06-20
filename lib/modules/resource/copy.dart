import 'dart:io';
import 'package:configr/events/module_events.dart';
import 'package:configr/exceptions.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/file_utils.dart';
import 'package:configr/utils/logging.dart';
import 'package:configr/utils/event_bus.dart';
import 'package:path/path.dart' as path;
import 'package:glob/glob.dart';

/// Enhanced file copy module with selective copying, progress tracking, and conflict resolution.
/// 
/// Features:
/// - Selective copying using glob patterns (include/exclude)
/// - Progress tracking with detailed counters
/// - Multiple conflict resolution strategies
/// - Comprehensive event emission
/// - Rollback support
class FileCopyModule extends ResourceModule {
  // State getters
  bool get hadToCreateDstDir => state['hadToCreateDstDir'] as bool? ?? false;
  bool get destinationFileExisted => state['destinationFileExisted'] as bool? ?? false;
  String? get originalContent => state['originalContent'] as String?;
  String? get destinationDir => state['destinationDir'] as String?;
  String? get sourceHash => state['sourceHash'] as String?;
  bool get isDirectory => state['isDirectory'] as bool? ?? false;
  bool get recursive => state['recursive'] as bool? ?? false;
  
  // Enhanced features
  List<String> get includePatterns => (state['includePatterns'] as List<dynamic>?)?.cast<String>() ?? [];
  List<String> get excludePatterns => (state['excludePatterns'] as List<dynamic>?)?.cast<String>() ?? [];
  String get conflictResolution => state['conflictResolution'] as String? ?? 'skip';
  bool get showProgress => state['showProgress'] as bool? ?? true;
  int get copiedFiles => state['copiedFiles'] as int? ?? 0;
  int get totalFiles => state['totalFiles'] as int? ?? 0;
  int get skippedFiles => state['skippedFiles'] as int? ?? 0;
  int get overwrittenFiles => state['overwrittenFiles'] as int? ?? 0;

  FileCopyModule(super.file, super.action,
      {super.allowedActions = const ['copy'], super.fileSystem}) {
    updateState({
      'hadToCreateDstDir': false,
      'destinationFileExisted': false,
      'originalContent': null,
      'sourceHash': null,
      'destinationDir': null,
      'isDirectory': false,
      'recursive': false,
      'includePatterns': [],
      'excludePatterns': [],
      'conflictResolution': 'skip',
      'showProgress': true,
      'copiedFiles': 0,
      'totalFiles': 0,
      'skippedFiles': 0,
      'overwrittenFiles': 0,
    });
  }

  @override
  Future<void> execute() async {
    emitEvent(StartedEvent(moduleId: action.id, message: 'Starting copy of $source to $destination'));
    
    // Parse configuration
    final config = _parseConfiguration();
    updateState(config);

    final existCheck = await FileUtils.pathExists(source, fileSystem: fileSystem);
    if (!existCheck.exists) {
      throw SourceNotFoundException(source);
    }

    updateState({'isDirectory': existCheck.isDir});

    await executeModules();
    if (isRollingBack) {
      return;
    }

    final destDir = isDirectory ? destination : path.dirname(destination);
    updateState({'destinationDir': destDir});

    if (!await FileUtils.directoryExists(destDir, fileSystem: fileSystem)) {
      logger.info('Creating directory $destDir');
      try {
        await FileUtils.createDirectory(destDir, fileSystem: fileSystem);
        updateState({'hadToCreateDstDir': true});
      } catch (e, s) {
        throw ActionFailedException('Failed to create directory $destDir', moduleId: action.id, cause: e, stackTrace: s);
      }
    }

    final exists = await (!isDirectory
        ? FileUtils.fileExists(destination, fileSystem: fileSystem)
        : FileUtils.directoryExists(destination, fileSystem: fileSystem));

    try {
      if (exists) {
        final content = await FileUtils.readFile(destination, fileSystem: fileSystem);
        updateState({
          'destinationFileExisted': true,
          'originalContent': content,
        });
      }

      final hash = await FileUtils.computeFileHash(source, fileSystem: fileSystem);
      updateState({'sourceHash': hash});
    } catch (e, st) {
      logger.warning('Failed to update state', e, st);
    }

    await executeModules();
    if (isRollingBack) {
      return;
    }

    try {
      if (isDirectory) {
        await _copyDirectoryWithProgress();
      } else {
        await _copyFileWithProgress();
      }
      updateState({'copyCompleted': true});
      emitEvent(CompletedEvent(moduleId: action.id, message: 'Copy completed successfully - $copiedFiles files copied, $skippedFiles skipped, $overwrittenFiles overwritten'));
    } catch (e, st) {
      updateState({
        'error': e.toString(),
        'stackTrace': st.toString()
      });
      emitEvent(FailedEvent(moduleId: action.id, message: 'Copy failed: ${e.toString()}'));
      throw ActionFailedException('Failed to copy', moduleId: action.id, cause: e, stackTrace: st);
    }

    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
    await saveState();
  }

  @override
  Future<void> rollback() async {
    emitEvent(StartedEvent(moduleId: action.id, message: 'Rolling back copy operation'));
    
    try {
      if (isDirectory) {
        if (await FileUtils.directoryExists(destination, fileSystem: fileSystem)) {
          logger.info('Deleting created directory $destination');
          await FileUtils.deleteDirectory(destination,
              recursive: true, fileSystem: fileSystem);
        }
      } else {
        if (await FileUtils.fileExists(destination, fileSystem: fileSystem)) {
          if (!destinationFileExisted) {
            await FileUtils.deleteFile(destination, fileSystem: fileSystem);
          } else if (originalContent != null) {
            await FileUtils.writeFile(
              destination,
              originalContent!,
              fileSystem: fileSystem,
            );
          }
        }

        if (hadToCreateDstDir && destinationDir != null) {
          if (await FileUtils.directoryExists(destinationDir!)) {
            final contents = await fileSystem!.directory(destinationDir).list().toList();
            if (contents.isEmpty) {
              await FileUtils.deleteDirectory(
                destinationDir!,
                recursive: true,
                fileSystem: fileSystem,
              );
            }
          }
        }
      }

      for (var module in childModules) {
        await module.rollback();
      }

      updateState({'rollbackCompleted': true});
      emitEvent(CompletedEvent(moduleId: action.id, message: 'Copy rollback completed'));
      await saveState();
    } catch (e, st) {
      updateState({
        'rollbackError': e.toString(),
        'rollbackStackTrace': st.toString()
      });
      emitEvent(FailedEvent(moduleId: action.id, message: 'Copy rollback failed: ${e.toString()}'));
      rethrow;
    }
  }

  /// Parse configuration from action properties.
  /// 
  /// Extracts include/exclude patterns, conflict resolution strategy, and other
  /// configuration options from the action properties.
  /// 
  /// Returns a map of configuration values to be stored in module state.
  Map<String, dynamic> _parseConfiguration() {
    final includePatterns = <String>[];
    final excludePatterns = <String>[];
    
    // Parse include patterns
    if (action.properties.containsKey('include')) {
      final include = action.properties['include'];
      if (include is String) {
        includePatterns.addAll(include.split(',').map((s) => s.trim()));
      } else if (include is List) {
        includePatterns.addAll(include.cast<String>());
      }
    }
    
    // Parse exclude patterns
    if (action.properties.containsKey('exclude')) {
      final exclude = action.properties['exclude'];
      if (exclude is String) {
        excludePatterns.addAll(exclude.split(',').map((s) => s.trim()));
      } else if (exclude is List) {
        excludePatterns.addAll(exclude.cast<String>());
      }
    }
    
    return {
      'recursive': action.properties.containsKey('recursive') && action.properties['recursive'] == 'true',
      'includePatterns': includePatterns,
      'excludePatterns': excludePatterns,
      'conflictResolution': action.properties['conflict_resolution'] ?? 'skip',
      'showProgress': action.properties['show_progress'] != 'false',
    };
  }

  /// Copy a single file with progress tracking and pattern filtering.
  /// 
  /// This method handles:
  /// - Pattern-based inclusion/exclusion
  /// - Conflict resolution
  /// - Progress tracking
  /// - Event emission
  Future<void> _copyFileWithProgress() async {
    emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Copying file...'));
    
    // Check if file should be included/excluded
    if (!_shouldIncludeFile(source)) {
      updateState({'skippedFiles': skippedFiles + 1});
      emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Skipped file (excluded): $source'));
      return;
    }
    
    // Handle conflict resolution
    final destExists = await FileUtils.fileExists(destination, fileSystem: fileSystem);
    if (destExists) {
      switch (conflictResolution) {
        case 'skip':
          updateState({'skippedFiles': skippedFiles + 1});
          emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Skipped file (exists): $destination'));
          return;
        case 'overwrite':
          updateState({'overwrittenFiles': overwrittenFiles + 1});
          emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Overwriting file: $destination'));
          break;
        case 'merge':
          // For now, treat merge as overwrite
          updateState({'overwrittenFiles': overwrittenFiles + 1});
          emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Merging file: $destination'));
          break;
      }
    }
    
    await FileUtils.copyFile(source, destination, fileSystem: fileSystem);
    updateState({'copiedFiles': copiedFiles + 1});
    emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Copied file: $source -> $destination'));
  }

  /// Copy directory with progress tracking and selective copying.
  /// 
  /// This method:
  /// - Scans the directory for files matching patterns
  /// - Tracks progress for each file
  /// - Emits progress events
  /// - Handles directory creation
  Future<void> _copyDirectoryWithProgress() async {
    emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Scanning directory...'));
    
    // First, scan to get total file count
    final filesToCopy = await _scanDirectoryForFiles(source);
    updateState({'totalFiles': filesToCopy.length});
    
    emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Found ${filesToCopy.length} files to process'));
    
    // Copy files with progress tracking
    for (int i = 0; i < filesToCopy.length; i++) {
      final filePath = filesToCopy[i];
      final relativePath = path.relative(filePath, from: source);
      final destPath = path.join(destination, relativePath);
      
      // Update progress
      if (showProgress) {
        final progress = ((i + 1) / filesToCopy.length * 100).round();
        emitEvent(ProgressEvent(
          moduleId: action.id,
          current: i + 1,
          total: filesToCopy.length,
          message: 'Copying $relativePath ($progress%)'
        ));
      }
      
      // Ensure destination directory exists
      final destDir = path.dirname(destPath);
      if (!await FileUtils.directoryExists(destDir, fileSystem: fileSystem)) {
        await FileUtils.createDirectory(destDir, fileSystem: fileSystem);
      }
      
      // Copy the file
      await _copyFileWithProgressInternal(filePath, destPath);
    }
  }

  /// Internal method to copy a file with conflict resolution.
  /// 
  /// This is used by the directory copying method to handle individual files
  /// with proper pattern filtering and conflict resolution.
  Future<void> _copyFileWithProgressInternal(String sourcePath, String destPath) async {
    // Check if file should be included/excluded
    if (!_shouldIncludeFile(sourcePath)) {
      updateState({'skippedFiles': skippedFiles + 1});
      return;
    }
    
    // Handle conflict resolution
    final destExists = await FileUtils.fileExists(destPath, fileSystem: fileSystem);
    if (destExists) {
      switch (conflictResolution) {
        case 'skip':
          updateState({'skippedFiles': skippedFiles + 1});
          return;
        case 'overwrite':
          updateState({'overwrittenFiles': overwrittenFiles + 1});
          break;
        case 'merge':
          // For now, treat merge as overwrite
          updateState({'overwrittenFiles': overwrittenFiles + 1});
          break;
      }
    }
    
    await FileUtils.copyFile(sourcePath, destPath, fileSystem: fileSystem);
    updateState({'copiedFiles': copiedFiles + 1});
  }

  /// Scan directory for files that match include/exclude patterns.
  /// 
  /// Returns a list of file paths that should be processed based on the
  /// configured include/exclude patterns.
  Future<List<String>> _scanDirectoryForFiles(String dirPath) async {
    final files = <String>[];
    final dir = fileSystem!.directory(dirPath);
    
    await for (final entity in dir.list(recursive: recursive)) {
      if (entity is File) {
        files.add(entity.path);
      }
    }
    
    return files;
  }

  /// Check if a file should be included based on include/exclude patterns.
  /// 
  /// Returns true if the file should be processed, false if it should be skipped.
  /// Exclude patterns take precedence over include patterns.
  bool _shouldIncludeFile(String filePath) {
    final fileName = path.basename(filePath);
    final relativePath = path.relative(filePath, from: source);
    
    // Check exclude patterns first
    for (final pattern in excludePatterns) {
      if (_matchesPattern(fileName, pattern) || _matchesPattern(relativePath, pattern)) {
        return false;
      }
    }
    
    // If no include patterns, include all files
    if (includePatterns.isEmpty) {
      return true;
    }
    
    // Check include patterns
    for (final pattern in includePatterns) {
      if (_matchesPattern(fileName, pattern) || _matchesPattern(relativePath, pattern)) {
        return true;
      }
    }
    
    return false;
  }

  /// Pattern matching using glob patterns.
  /// 
  /// Uses the glob package for robust pattern matching. Falls back to exact
  /// matching if the pattern is invalid.
  bool _matchesPattern(String text, String pattern) {
    try {
      final glob = Glob(pattern);
      return glob.matches(text);
    } catch (e) {
      // If glob pattern is invalid, fall back to exact match
      return text == pattern;
    }
  }
}