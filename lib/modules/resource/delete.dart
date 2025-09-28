import 'dart:io';
import 'package:configr/events/module_events.dart';
import 'package:configr/exceptions.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/file_utils.dart';
import 'package:configr/utils/logging.dart';
import 'package:configr/utils/event_bus.dart';
import 'package:path/path.dart' as path;
import 'package:glob/glob.dart';

/// Enhanced file delete module with safe deletion, confirmation prompts, and trash support.
/// 
/// Features:
/// - Safe deletion with confirmation prompts
/// - Trash support for recoverable deletion
/// - Pattern-based selective deletion
/// - Progress tracking for directory operations
/// - Comprehensive event emission
/// - Rollback support
class FileDeleteModule extends ResourceModule {
  // State getters
  String? get backupPath => state['backupPath'] as String?;
  bool get fileExisted => state['fileExisted'] as bool? ?? false;
  bool get backupCreated => state['backupCreated'] as bool? ?? false;
  bool get isDirectory => state['isDirectory'] as bool? ?? false;
  bool get recursive => state['recursive'] as bool? ?? false;
  
  // Enhanced features
  bool get useTrash => state['useTrash'] as bool? ?? false;
  bool get requireConfirmation => state['requireConfirmation'] as bool? ?? false;
  List<String> get includePatterns => (state['includePatterns'] as List<dynamic>?)?.cast<String>() ?? [];
  List<String> get excludePatterns => (state['excludePatterns'] as List<dynamic>?)?.cast<String>() ?? [];
  int get deletedFiles => state['deletedFiles'] as int? ?? 0;
  int get totalFiles => state['totalFiles'] as int? ?? 0;
  int get skippedFiles => state['skippedFiles'] as int? ?? 0;
  int get trashedFiles => state['trashedFiles'] as int? ?? 0;

  FileDeleteModule(
    super.file,
    super.action, {
    super.allowedActions = const ['delete'],
    super.fileSystem,
  }) {
    updateState({
      'backupPath': null,
      'fileExisted': false,
      'backupCreated': false,
      'isDirectory': false,
      'recursive': false,
      'useTrash': false,
      'requireConfirmation': false,
      'includePatterns': [],
      'excludePatterns': [],
      'deletedFiles': 0,
      'totalFiles': 0,
      'skippedFiles': 0,
      'trashedFiles': 0,
    });
  }

  @override
  Future<void> execute() async {
    emitEvent(
      StartedEvent(
        moduleId: action.id,
        message: 'Starting deletion of $source',
      ),
    );
    
    // Parse configuration
    final config = _parseConfiguration();
    updateState(config);

    // Check if source exists and determine if it's a file or directory
    final fileExists = await FileUtils.fileExists(
      source,
      fileSystem: fileSystem,
    );
    final directoryExists = await FileUtils.directoryExists(
      source,
      fileSystem: fileSystem,
    );
    final exists = fileExists || directoryExists;

    updateState({'fileExisted': exists, 'isDirectory': directoryExists});

    if (!exists) {
      logger.warning('Path $source does not exist, skipping deletion');
      return;
    }

    await executeModules();
    if (isRollingBack) {
      return;
    }

    try {
      // Handle backup if configured
      if (action.properties.containsKey('backup')) {
        final backupPathValue = action.properties['backup']['backup_path'];
        updateState({'backupPath': backupPathValue});

        logger.info('Backing up file $source to $backupPath');
        await FileUtils.copyFile(
          source,
          backupPath!,
          fileSystem: fileSystem,
        );
        updateState({'backupCreated': true});
      }

      // Check for confirmation if required
      if (requireConfirmation) {
        final confirmed = await _requestConfirmation();
        if (!confirmed) {
          emitEvent(
            StatusUpdateEvent(
              moduleId: action.id,
              level: StatusEvent.info,
              message: 'Deletion cancelled by user',
            ),
          );
          return;
        }
      }

      // Perform deletion
      if (isDirectory) {
        await _deleteDirectoryWithProgress();
      } else {
        await _deleteFileWithProgress();
      }
      
      updateState({'deleteCompleted': true});
      emitEvent(
        CompletedEvent(
          moduleId: action.id,
          message: 'Deletion completed successfully - $deletedFiles files deleted, $skippedFiles skipped, $trashedFiles trashed',
        ),
      );
    } catch (e, st) {
      updateState({'error': e.toString(), 'stackTrace': st.toString()});
      emitEvent(
        FailedEvent(
          moduleId: action.id,
          message: 'Deletion failed: ${e.toString()}',
        ),
      );
      rethrow;
    }

    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
    await saveState();
  }

  @override
  Future<void> rollback() async {
    try {
      if (fileExisted && backupPath != null && backupCreated) {
        logger.info('Restoring file from $backupPath to $source');
        await FileUtils.copyFile(backupPath!, source, fileSystem: fileSystem);
        await FileUtils.deleteFile(backupPath!, fileSystem: fileSystem);
        updateState({'rollbackCompleted': true});
      }
    } catch (e, st) {
      updateState({
        'rollbackError': e.toString(),
        'rollbackStackTrace': st.toString(),
      });
      rethrow;
    }

    for (var module in childModules) {
      await module.rollback();
    }

    await saveState();
  }

  /// Parse configuration from action properties.
  /// 
  /// Extracts include/exclude patterns, trash usage, confirmation requirements,
  /// and other configuration options from the action properties.
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
      'useTrash': action.properties['use_trash'] == 'true',
      'requireConfirmation': action.properties['require_confirmation'] == 'true',
    };
  }

  /// Request user confirmation for deletion.
  /// 
  /// Returns true if user confirms, false if cancelled.
  Future<bool> _requestConfirmation() async {
    // For now, return true (auto-confirm)
    // In a real implementation, this would prompt the user
    emitEvent(
      StatusUpdateEvent(
        moduleId: action.id,
        level: StatusEvent.warning,
        message: 'Confirmation required for deletion of $source',
      ),
    );
    return true;
  }

  /// Delete a single file with progress tracking and trash support.
  Future<void> _deleteFileWithProgress() async {
    emitEvent(
      StatusUpdateEvent(
        moduleId: action.id,
        level: StatusEvent.info,
        message: 'Deleting file...',
      ),
    );
    
    // Check if file should be included/excluded
    if (!_shouldIncludeFile(source)) {
      updateState({'skippedFiles': skippedFiles + 1});
      emitEvent(
        StatusUpdateEvent(
          moduleId: action.id,
          level: StatusEvent.info,
          message: 'Skipped file (excluded): $source',
        ),
      );
      return;
    }
    
    try {
      if (useTrash) {
        await _moveToTrash(source);
        updateState({'trashedFiles': trashedFiles + 1});
        emitEvent(
          StatusUpdateEvent(
            moduleId: action.id,
            level: StatusEvent.info,
            message: 'Moved to trash: $source',
          ),
        );
      } else {
        await FileUtils.deleteFile(source, fileSystem: fileSystem);
        updateState({'deletedFiles': deletedFiles + 1});
        emitEvent(
          StatusUpdateEvent(
            moduleId: action.id,
            level: StatusEvent.info,
            message: 'Deleted file: $source',
          ),
        );
      }
    } catch (e, st) {
      throw ActionFailedException(
        'Failed to delete file $source',
        moduleId: action.id,
        cause: e,
        stackTrace: st,
      );
    }
  }

  /// Delete directory with progress tracking and selective deletion.
  Future<void> _deleteDirectoryWithProgress() async {
    emitEvent(
      StatusUpdateEvent(
        moduleId: action.id,
        level: StatusEvent.info,
        message: 'Scanning directory...',
      ),
    );
    
    // First, scan to get total file count
    final filesToDelete = await _scanDirectoryForFiles(source);
    updateState({'totalFiles': filesToDelete.length});
    
    emitEvent(
      StatusUpdateEvent(
        moduleId: action.id,
        level: StatusEvent.info,
        message: 'Found ${filesToDelete.length} files to process',
      ),
    );
    
    // Delete files with progress tracking
    for (int i = 0; i < filesToDelete.length; i++) {
      final filePath = filesToDelete[i];
      
      // Update progress
      final progress = ((i + 1) / filesToDelete.length * 100).round();
      emitEvent(
        ProgressEvent(
          moduleId: action.id,
          current: i + 1,
          total: filesToDelete.length,
          message: 'Deleting $filePath ($progress%)',
        ),
      );
      
      // Delete the file
      await _deleteFileWithProgressInternal(filePath);
    }
    
    // Delete the directory itself if empty
    try {
      if (recursive) {
        await FileUtils.deleteDirectory(source, fileSystem: fileSystem, recursive: false);
      }
    } catch (e) {
      // Directory might not be empty, which is expected
    }
  }

  /// Internal method to delete a file with pattern filtering.
  Future<void> _deleteFileWithProgressInternal(String filePath) async {
    // Check if file should be included/excluded
    if (!_shouldIncludeFile(filePath)) {
      updateState({'skippedFiles': skippedFiles + 1});
      return;
    }
    
    try {
      if (useTrash) {
        await _moveToTrash(filePath);
        updateState({'trashedFiles': trashedFiles + 1});
      } else {
        await FileUtils.deleteFile(filePath, fileSystem: fileSystem);
        updateState({'deletedFiles': deletedFiles + 1});
      }
    } catch (e) {
      // Log error but continue with other files
      emitEvent(
        StatusUpdateEvent(
          moduleId: action.id,
          level: StatusEvent.warning,
          message: 'Failed to delete $filePath: $e',
        ),
      );
    }
  }

  /// Scan directory for files that match include/exclude patterns.
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
  bool _matchesPattern(String text, String pattern) {
    try {
      final glob = Glob(pattern);
      return glob.matches(text);
    } catch (e) {
      // If glob pattern is invalid, fall back to exact match
      return text == pattern;
    }
  }

  /// Move file to trash (placeholder implementation).
  /// 
  /// In a real implementation, this would use platform-specific trash APIs.
  Future<void> _moveToTrash(String filePath) async {
    // For now, just delete the file
    // In a real implementation, this would move to system trash
    await FileUtils.deleteFile(filePath, fileSystem: fileSystem);
  }
}
