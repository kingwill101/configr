import 'dart:io';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/modules/resource/resource_module.dart';
import 'package:configr/src/utils/fs.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:path/path.dart' as path;
import 'package:file/file.dart';

/// Sync module for bidirectional file synchronization
class FileSyncModule extends ResourceModule {
  // State getters
  String get syncMode => state['syncMode'] as String? ?? 'bidirectional';
  String get conflictResolution => state['conflictResolution'] as String? ?? 'newer';
  int get bandwidthLimit => state['bandwidthLimit'] as int? ?? 0; // 0 = no limit
  bool get preservePermissions => state['preservePermissions'] as bool? ?? true;
  bool get preserveTimestamps => state['preserveTimestamps'] as bool? ?? true;
  bool get deleteOrphans => state['deleteOrphans'] as bool? ?? false;
  List<String> get excludePatterns => (state['excludePatterns'] as List<dynamic>?)?.cast<String>() ?? [];
  List<String> get includePatterns => (state['includePatterns'] as List<dynamic>?)?.cast<String>() ?? [];
  int get syncId => state['syncId'] as int? ?? 0;
  Map<String, String> get syncResults {
    final results = state['syncResults'];
    if (results == null) return {};
    if (results is Map<String, String>) return results;
    if (results is Map<String, dynamic>) {
      return results.map((key, value) => MapEntry(key, value.toString()));
    }
    if (results is Map<dynamic, dynamic>) {
      return results.map((key, value) => MapEntry(key.toString(), value.toString()));
    }
    return {};
  }
  int get filesProcessed => state['filesProcessed'] as int? ?? 0;
  int get conflictsResolved => state['conflictsResolved'] as int? ?? 0;
  int get errorsEncountered => state['errorsEncountered'] as int? ?? 0;

  FileSyncModule(super.file, super.action,
      {super.allowedActions = const ['sync'], super.fileSystem, super.eventBus}) {
    updateState({
      'syncMode': 'bidirectional',
      'conflictResolution': 'newer',
      'bandwidthLimit': 0,
      'preservePermissions': true,
      'preserveTimestamps': true,
      'deleteOrphans': false,
      'excludePatterns': [],
      'includePatterns': [],
      'syncId': 0,
      'syncResults': {},
      'filesProcessed': 0,
      'conflictsResolved': 0,
      'errorsEncountered': 0,
    });
    _loadConfiguration();
  }

  void _loadConfiguration() {
    final props = action.properties;
    
    updateState({
      'syncMode': props['sync_mode'] ?? syncMode,
      'conflictResolution': props['conflict_resolution'] ?? conflictResolution,
      'bandwidthLimit': props['bandwidth_limit'] ?? bandwidthLimit,
      'preservePermissions': props['preserve_permissions'] ?? preservePermissions,
      'preserveTimestamps': props['preserve_timestamps'] ?? preserveTimestamps,
      'deleteOrphans': props['delete_orphans'] ?? deleteOrphans,
    });

    if (props.containsKey('exclude_patterns')) {
      final patterns = props['exclude_patterns'] as List<dynamic>?;
      if (patterns != null) {
        updateState({'excludePatterns': patterns.cast<String>()});
      }
    }

    if (props.containsKey('include_patterns')) {
      final patterns = props['include_patterns'] as List<dynamic>?;
      if (patterns != null) {
        updateState({'includePatterns': patterns.cast<String>()});
      }
    }
  }

  @override
  Future<void> execute() async {
    emitEvent(StartedEvent(moduleId: action.id, message: 'Starting file synchronization'));

    try {
      final syncId = DateTime.now().millisecondsSinceEpoch;
      updateState({'syncId': syncId});

      if (source.isEmpty || destination.isEmpty) {
        throw ActionFailedException('Source and destination paths are required for sync');
      }

      final sourcePath = path.absolute(source);
      final destPath = path.absolute(destination);

    // Validate paths
    if (!(fileSystem ?? fs).directory(sourcePath).existsSync()) {
      throw ActionFailedException('Source path does not exist: $sourcePath');
    }

    // Create destination directory if it doesn't exist
    if (!(fileSystem ?? fs).directory(destPath).existsSync()) {
      (fileSystem ?? fs).directory(destPath).createSync(recursive: true);
      logger.info('Created destination directory: $destPath');
    }

      // Perform synchronization based on mode
      switch (syncMode.toLowerCase()) {
        case 'bidirectional':
          await _performBidirectionalSync(sourcePath, destPath);
          break;
        case 'source_to_dest':
          await _performSourceToDestSync(sourcePath, destPath);
          break;
        case 'dest_to_source':
          await _performDestToSourceSync(sourcePath, destPath);
          break;
        default:
          throw ActionFailedException('Invalid sync mode: $syncMode');
      }

      logger.info('Sync completed successfully. Files processed: $filesProcessed, Conflicts resolved: $conflictsResolved');
      emitEvent(CompletedEvent(moduleId: action.id, message: 'File synchronization completed successfully'));
    } catch (e) {
      updateState({'errorsEncountered': errorsEncountered + 1});
      emitEvent(FailedEvent(moduleId: action.id, message: 'Sync failed: $e'));
      rethrow;
    }
  }

  Future<void> _performBidirectionalSync(String sourcePath, String destPath) async {
    logger.info('Performing bidirectional synchronization');
    
    // Sync from source to destination
    await _syncDirectory(sourcePath, destPath, 'source_to_dest');
    
    // Sync from destination to source
    await _syncDirectory(destPath, sourcePath, 'dest_to_source');
  }

  Future<void> _performSourceToDestSync(String sourcePath, String destPath) async {
    logger.info('Performing source to destination synchronization');
    await _syncDirectory(sourcePath, destPath, 'source_to_dest');
  }

  Future<void> _performDestToSourceSync(String sourcePath, String destPath) async {
    logger.info('Performing destination to source synchronization');
    await _syncDirectory(destPath, sourcePath, 'dest_to_source');
  }

  Future<void> _syncDirectory(String fromPath, String toPath, String direction) async {
    final fromDir = (fileSystem ?? fs).directory(fromPath);
    final toDir = (fileSystem ?? fs).directory(toPath);

    if (!fromDir.existsSync()) {
      logger.warning('Source directory does not exist: $fromPath');
      return;
    }

    // Ensure destination directory exists
    if (!toDir.existsSync()) {
      toDir.createSync(recursive: true);
    }

    // Process files and directories
    await for (final entity in fromDir.list(recursive: true)) {
      if (entity is File) {
        await _syncFile(entity, fromPath, toPath, direction);
      } else if (entity is Directory) {
        final relativePath = path.relative(entity.path, from: fromPath);
        await _syncDirectory(entity.path, path.join(toPath, relativePath), direction);
      }
    }

    // Handle orphaned files if deleteOrphans is enabled
    if (deleteOrphans) {
      await _deleteOrphanedFiles(fromPath, toPath, direction);
    }
  }

  Future<void> _syncFile(FileSystemEntity sourceFile, String fromPath, String toPath, String direction) async {
    final relativePath = path.relative(sourceFile.path, from: fromPath);
    final destFile = (fileSystem ?? fs).file(path.join(toPath, relativePath));

    // Check if file should be excluded
    if (_shouldExcludeFile(relativePath)) {
      return;
    }

    // Check if file should be included
    if (!_shouldIncludeFile(relativePath)) {
      return;
    }

    updateState({'filesProcessed': filesProcessed + 1});

    try {
      // Check if destination file exists
      if (destFile.existsSync()) {
        // Handle conflict resolution
        final shouldSync = await _resolveConflict(sourceFile, destFile);
        if (!shouldSync) {
          return;
        }
        updateState({'conflictsResolved': conflictsResolved + 1});
      }

      // Copy file
      await _copyFileWithAttributes(sourceFile, destFile);
      
      final result = '${direction}: $relativePath';
      final results = Map<String, String>.from(syncResults);
      results[relativePath] = result;
      updateState({'syncResults': results});

      logger.info('Synced file: $relativePath ($direction)');
    } catch (e) {
      updateState({'errorsEncountered': errorsEncountered + 1});
      logger.severe('Failed to sync file $relativePath: $e');
      emitEvent(ProgressEvent(moduleId: action.id, message: 'Failed to sync file: $relativePath'));
    }
  }

  Future<bool> _resolveConflict(FileSystemEntity sourceFile, File destFile) async {
    if (sourceFile is! File) return false;
    
    switch (conflictResolution.toLowerCase()) {
      case 'newer':
        return sourceFile.lastModifiedSync().isAfter(destFile.lastModifiedSync());
      case 'source':
        return true;
      case 'destination':
        return false;
      case 'larger':
        return sourceFile.lengthSync() > destFile.lengthSync();
      case 'skip':
        return false;
      default:
        logger.warning('Unknown conflict resolution strategy: $conflictResolution, using newer');
        return sourceFile.lastModifiedSync().isAfter(destFile.lastModifiedSync());
    }
  }

  Future<void> _copyFileWithAttributes(FileSystemEntity sourceFile, File destFile) async {
    if (sourceFile is! File) return;
    
    // Ensure destination directory exists
    destFile.parent.createSync(recursive: true);

    // Copy file content
    await sourceFile.copy(destFile.path);

    // Preserve permissions if requested
    if (preservePermissions) {
      try {
        final sourceStat = sourceFile.statSync();
        final destStat = destFile.statSync();
        // Note: Dart doesn't provide direct permission copying, this is a placeholder
        logger.info('Permissions preservation requested but not implemented in Dart');
      } catch (e) {
        logger.warning('Failed to preserve permissions: $e');
      }
    }

    // Preserve timestamps if requested
    if (preserveTimestamps) {
      try {
        final sourceStat = sourceFile.statSync();
        destFile.setLastModifiedSync(sourceStat.modified);
        destFile.setLastAccessedSync(sourceStat.accessed);
      } catch (e) {
        logger.warning('Failed to preserve timestamps: $e');
      }
    }
  }

  Future<void> _deleteOrphanedFiles(String fromPath, String toPath, String direction) async {
    final toDir = (fileSystem ?? fs).directory(toPath);
    if (!toDir.existsSync()) return;

    await for (final entity in toDir.list(recursive: true)) {
      if (entity is File) {
        final relativePath = path.relative(entity.path, from: toPath);
        final sourceFile = (fileSystem ?? fs).file(path.join(fromPath, relativePath));
        
        if (!sourceFile.existsSync() && _shouldIncludeFile(relativePath)) {
          try {
            entity.deleteSync();
            logger.info('Deleted orphaned file: $relativePath');
            updateState({'filesProcessed': filesProcessed + 1});
          } catch (e) {
            logger.severe('Failed to delete orphaned file $relativePath: $e');
            updateState({'errorsEncountered': errorsEncountered + 1});
          }
        }
      }
    }
  }

  bool _shouldExcludeFile(String filePath) {
    if (excludePatterns.isEmpty) return false;
    
    // Simple pattern matching - handle basic glob patterns
    for (final pattern in excludePatterns) {
      if (_matchesPattern(filePath, pattern)) {
        return true;
      }
    }
    return false;
  }

  bool _shouldIncludeFile(String filePath) {
    if (includePatterns.isEmpty) return true;
    
    // Simple pattern matching - handle basic glob patterns
    for (final pattern in includePatterns) {
      if (_matchesPattern(filePath, pattern)) {
        return true;
      }
    }
    return false;
  }

  bool _matchesPattern(String filePath, String pattern) {
    // Handle simple glob patterns like *.txt, *.tmp
    if (pattern.startsWith('*.')) {
      final extension = pattern.substring(1); // Remove the *
      return filePath.endsWith(extension);
    }
    
    // Handle exact matches
    if (pattern == filePath) return true;
    
    // Handle simple suffix matches
    if (filePath.endsWith(pattern)) return true;
    
    return false;
  }

  @override
  Future<void> rollback() async {
    emitEvent(StartedEvent(moduleId: action.id, message: 'Starting sync module rollback'));
    
    try {
      // For sync operations, rollback is complex as we don't track original state
      // This is a simplified rollback that logs the operation
      logger.info('Sync rollback: This operation cannot be fully rolled back as original file states are not tracked');
      logger.info('Sync results: $syncResults');
      
      emitEvent(CompletedEvent(moduleId: action.id, message: 'Sync module rollback completed (limited rollback capability)'));
    } catch (e) {
      emitEvent(FailedEvent(moduleId: action.id, message: 'Failed to rollback sync: $e'));
      rethrow;
    }
  }
}
