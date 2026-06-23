import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/file_utils.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:file/file.dart' show File;
import 'package:i3config/i3config_v2.dart' as i3;
import 'package:path/path.dart' as path;

/// Block handler for the `sync` config action.
///
/// Bidirectional file synchronization between source and destination
/// directories with conflict resolution.
///
/// ```i3
/// sync {
///   source = "/path/to/source"
///   destination = "/path/to/dest"
///   mode = "bidirectional"          # bidirectional | source_to_dest | dest_to_source
///   conflict_resolution = "newer"   # newer | source | destination | larger | skip
///   preserve_timestamps = true
///   preserve_permissions = true
///   delete_orphans = false
/// }
/// ```
class SyncBlock extends ActionBlock {
  @override
  String get blockType => 'sync';

  // ---------------------------------------------------------------------------
  // Sync-specific properties
  // ---------------------------------------------------------------------------

  String operation = 'sync';
  String syncMode = 'bidirectional';
  String conflictResolution = 'newer';
  bool preserveTimestamps = true;
  bool preservePermissions = true;
  bool deleteOrphans = false;
  List<String> includePatterns = [];
  List<String> excludePatterns = [];

  // ---------------------------------------------------------------------------
  // Execution state
  // ---------------------------------------------------------------------------

  int filesProcessed = 0;
  int conflictsResolved = 0;
  int errorsEncountered = 0;
  Map<String, String> syncResults = {};

  SyncBlock();

  // ---------------------------------------------------------------------------
  // Handler pipeline
  // ---------------------------------------------------------------------------

  @override
  Map<String, String> get additionalProperties => {
    if (syncMode != 'bidirectional') 'mode': syncMode,
    if (conflictResolution != 'newer')
      'conflict_resolution': conflictResolution,
    if (includePatterns.isNotEmpty) 'include': includePatterns.join(', '),
    if (excludePatterns.isNotEmpty) 'exclude': excludePatterns.join(', '),
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (preserveTimestamps) 'preserve_timestamps': preserveTimestamps,
    if (preservePermissions) 'preserve_permissions': preservePermissions,
    if (deleteOrphans) 'delete_orphans': deleteOrphans,
  };

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);

    operation = context.getVariable('operation') as String? ?? operation;
    syncMode = (context.getVariable('mode') as String?) ?? 'bidirectional';
    conflictResolution =
        (context.getVariable('conflict_resolution') as String?) ?? 'newer';

    preserveTimestamps = switch (context.getVariable('preserve_timestamps')) {
      false || 'false' => false,
      _ => true,
    };

    preservePermissions = switch (context.getVariable('preserve_permissions')) {
      false || 'false' => false,
      _ => true,
    };

    deleteOrphans = switch (context.getVariable('delete_orphans')) {
      true || 'true' => true,
      _ => false,
    };

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

    // v1 compat: fall back to include_patterns / exclude_patterns if
    // include / exclude were not set.
    if (includePatterns.isEmpty) {
      final legacyInclude = context.getVariable('include_patterns');
      if (legacyInclude is String) {
        includePatterns = legacyInclude
            .split(',')
            .map((s) => s.trim())
            .toList();
      } else if (legacyInclude is List) {
        includePatterns = legacyInclude.cast<String>();
      }
    }

    if (excludePatterns.isEmpty) {
      final legacyExclude = context.getVariable('exclude_patterns');
      if (legacyExclude is String) {
        excludePatterns = legacyExclude
            .split(',')
            .map((s) => s.trim())
            .toList();
      } else if (legacyExclude is List) {
        excludePatterns = legacyExclude.cast<String>();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Execution
  // ---------------------------------------------------------------------------

  @override
  Future<void> execute() async {
    emitEvent(
      StartedEvent(moduleId: id, message: 'Starting file synchronization'),
    );

    if (source.isEmpty || destination.isEmpty) {
      throw ActionFailedException(
        'Source and destination are required for sync',
        moduleId: id,
      );
    }

    final sourcePath = path.absolute(source);
    final destPath = path.absolute(destination);

    // Validate source exists
    if (!await FileUtils.directoryExists(sourcePath, fileSystem: fileSystem)) {
      throw ActionFailedException(
        'Source path does not exist: $sourcePath',
        moduleId: id,
      );
    }

    // Create destination if it doesn't exist
    if (!await FileUtils.directoryExists(destPath, fileSystem: fileSystem)) {
      await FileUtils.createDirectory(destPath, fileSystem: fileSystem);
    }

    try {
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
          throw ActionFailedException(
            'Invalid sync mode: $syncMode',
            moduleId: id,
          );
      }

      emitEvent(
        CompletedEvent(
          moduleId: id,
          message:
              'Sync completed — $filesProcessed files processed, '
              '$conflictsResolved conflicts resolved',
        ),
      );
    } catch (e, _) {
      errorsEncountered++;
      emitEvent(FailedEvent(moduleId: id, message: 'Sync failed: $e'));
      throw ActionFailedException(
        'Sync failed between $source and $destination',
        cause: e,
        moduleId: id,
      );
    }

    status = 'completed';
  }

  @override
  Future<void> rollback() async {
    // Sync operations are read-only in terms of tracking original state,
    // so rollback is a no-op that just logs.
    logger.warning(
      'Sync rollback: original file states are not tracked. '
      'Sync results: $syncResults',
    );

    for (final child in children) {
      await child.rollback();
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<void> _performBidirectionalSync(
    String sourcePath,
    String destPath,
  ) async {
    await _syncDirectory(sourcePath, destPath, 'source_to_dest');
    await _syncDirectory(destPath, sourcePath, 'dest_to_source');
  }

  Future<void> _performSourceToDestSync(
    String sourcePath,
    String destPath,
  ) async {
    await _syncDirectory(sourcePath, destPath, 'source_to_dest');
  }

  Future<void> _performDestToSourceSync(
    String sourcePath,
    String destPath,
  ) async {
    await _syncDirectory(destPath, sourcePath, 'dest_to_source');
  }

  Future<void> _syncDirectory(
    String fromPath,
    String toPath,
    String direction,
  ) async {
    final fromDir = fileSystem!.directory(fromPath);

    await for (final entity in fromDir.list(recursive: true)) {
      if (entity is File) {
        await _syncFile(entity, fromPath, toPath, direction);
      }
    }

    // Handle orphaned files if enabled
    if (deleteOrphans) {
      await _deleteOrphanedFiles(fromPath, toPath, direction);
    }
  }

  Future<void> _syncFile(
    File sourceFile,
    String fromPath,
    String toPath,
    String direction,
  ) async {
    final relativePath = path.relative(sourceFile.path, from: fromPath);
    final destFile = fileSystem!.file(path.join(toPath, relativePath));

    // Check exclude patterns
    for (final pattern in excludePatterns) {
      if (_matchesPattern(relativePath, pattern)) return;
    }

    // Check include patterns
    if (includePatterns.isNotEmpty &&
        !includePatterns.any((p) => _matchesPattern(relativePath, p))) {
      return;
    }

    filesProcessed++;

    try {
      if (await destFile.exists()) {
        final shouldSync = await _resolveConflict(sourceFile, destFile);
        if (!shouldSync) return;
        conflictsResolved++;
      }

      // Ensure destination directory exists
      final destDir = destFile.parent;
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      }

      await sourceFile.copy(destFile.path);

      // Preserve timestamps
      if (preserveTimestamps) {
        try {
          final sourceStat = await sourceFile.stat();
          await destFile.setLastModified(sourceStat.modified);
          await destFile.setLastAccessed(sourceStat.accessed);
        } catch (e) {
          logger.warning('Failed to preserve timestamps: $e');
        }
      }

      syncResults[relativePath] = '$direction: synced';
    } catch (e) {
      errorsEncountered++;
      logger.severe('Failed to sync file $relativePath: $e');
      syncResults[relativePath] = '$direction: failed';
    }
  }

  Future<bool> _resolveConflict(File sourceFile, File destFile) async {
    switch (conflictResolution.toLowerCase()) {
      case 'newer':
        final sourceStat = await sourceFile.stat();
        final destStat = await destFile.stat();
        return sourceStat.modified.isAfter(destStat.modified);
      case 'source':
        return true;
      case 'destination':
        return false;
      case 'larger':
        final sourceLen = await sourceFile.length();
        final destLen = await destFile.length();
        return sourceLen > destLen;
      case 'skip':
        return false;
      default:
        final sourceStat = await sourceFile.stat();
        final destStat = await destFile.stat();
        return sourceStat.modified.isAfter(destStat.modified);
    }
  }

  Future<void> _deleteOrphanedFiles(
    String fromPath,
    String toPath,
    String direction,
  ) async {
    final toDir = fileSystem!.directory(toPath);
    if (!await toDir.exists()) return;

    await for (final entity in toDir.list(recursive: true)) {
      if (entity is File) {
        final relativePath = path.relative(entity.path, from: toPath);
        final sourceFile = fileSystem!.file(path.join(fromPath, relativePath));

        if (!await sourceFile.exists()) {
          try {
            await entity.delete();
            filesProcessed++;
            syncResults[relativePath] = '$direction: orphan deleted';
          } catch (e) {
            errorsEncountered++;
            logger.severe('Failed to delete orphan $relativePath: $e');
          }
        }
      }
    }
  }

  bool _matchesPattern(String text, String pattern) {
    if (pattern.startsWith('*.')) {
      return text.endsWith(pattern.substring(1));
    }
    if (pattern == text) return true;
    if (text.endsWith(pattern)) return true;
    return false;
  }
}
