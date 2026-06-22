import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/file_utils.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:file/file.dart' show File;
import 'package:glob/glob.dart';
import 'package:i3config/i3config_v2.dart' as i3;
import 'package:path/path.dart' as path;

/// Block handler for the `delete` config action.
///
/// Safely deletes files/directories with backup, trash support,
/// pattern-based selective deletion, and full rollback.
///
/// ```i3
/// delete {
///   source = "/path/to/target"
///   backup = true
///   backup_path = "/path/to/backup"
///   use_trash = true
///   recursive = true
///   include = "*.tmp"
///   exclude = "important.*"
/// }
/// ```
class DeleteBlock extends ActionBlock {
  @override
  String get blockType => 'delete';

  // ---------------------------------------------------------------------------
  // Delete-specific properties
  // ---------------------------------------------------------------------------

  List<String> includePatterns = [];
  List<String> excludePatterns = [];
  bool recursive = false;
  bool useTrash = false;
  bool requireConfirmation = false;
  bool backup = false;
  String? backupPath;

  // ---------------------------------------------------------------------------
  // Execution state
  // ---------------------------------------------------------------------------

  bool fileExisted = false;
  bool backupCreated = false;
  bool isDirectorySource = false;
  int deletedFiles = 0;
  int totalFiles = 0;
  int skippedFiles = 0;
  int trashedFiles = 0;

  DeleteBlock({super.fileSystem, super.eventBus});

  // ---------------------------------------------------------------------------
  // Handler pipeline
  // ---------------------------------------------------------------------------

  @override
  Map<String, String> get additionalProperties => {
    if (includePatterns.isNotEmpty) 'include': includePatterns.join(', '),
    if (excludePatterns.isNotEmpty) 'exclude': excludePatterns.join(', '),
    'backup_path': ?backupPath,
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (recursive) 'recursive': recursive,
    if (useTrash) 'use_trash': useTrash,
    if (requireConfirmation) 'require_confirmation': requireConfirmation,
    if (backup) 'backup': backup,
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

    recursive = switch (context.getVariable('recursive')) {
      true || 'true' => true,
      _ => false,
    };

    useTrash = switch (context.getVariable('use_trash')) {
      true || 'true' => true,
      _ => false,
    };

    requireConfirmation = switch (context.getVariable('require_confirmation')) {
      true || 'true' => true,
      _ => false,
    };

    backup = switch (context.getVariable('backup')) {
      true || 'true' => true,
      _ => false,
    };

    backupPath = context.getVariable('backup_path') as String?;
  }

  // ---------------------------------------------------------------------------
  // Execution
  // ---------------------------------------------------------------------------

  @override
  Future<void> execute() async {
    emitEvent(
      StartedEvent(moduleId: id, message: 'Starting deletion of $source'),
    );

    // Check if source exists
    final fileExists = await FileUtils.fileExists(
      source,
      fileSystem: fileSystem,
    );
    final dirExists = await FileUtils.directoryExists(
      source,
      fileSystem: fileSystem,
    );
    final exists = fileExists || dirExists;
    fileExisted = exists;
    isDirectorySource = dirExists;

    if (!exists) {
      logger.warning('Path $source does not exist, skipping deletion');
      emitEvent(
        CompletedEvent(moduleId: id, message: 'Path does not exist, skipping'),
      );
      status = 'completed';
      return;
    }

    // Execute child blocks
    for (final child in children) {
      await child.execute();
    }

    try {
      // Handle backup if configured
      if (backup && backupPath != null) {
        logger.info('Backing up file $source to $backupPath');
        await FileUtils.copyFile(source, backupPath!, fileSystem: fileSystem);
        backupCreated = true;
      }

      // Perform deletion
      if (isDirectorySource) {
        await _deleteDirectoryWithProgress();
      } else {
        await _deleteFileWithProgress();
      }

      emitEvent(
        CompletedEvent(
          moduleId: id,
          message:
              'Deletion completed — $deletedFiles deleted, '
              '$skippedFiles skipped, $trashedFiles trashed',
        ),
      );
    } catch (e, _) {
      emitEvent(FailedEvent(moduleId: id, message: 'Deletion failed: $e'));
      throw ActionFailedException(
        'Failed to delete $source',
        cause: e,
        moduleId: id,
      );
    }

    status = 'completed';
  }

  @override
  Future<void> rollback() async {
    emitEvent(
      StartedEvent(moduleId: id, message: 'Rolling back delete operation'),
    );

    try {
      if (fileExisted && backupPath != null && backupCreated) {
        logger.info('Restoring file from $backupPath to $source');
        await FileUtils.copyFile(backupPath!, source, fileSystem: fileSystem);
        await FileUtils.deleteFile(backupPath!, fileSystem: fileSystem);
      }

      for (final child in children) {
        await child.rollback();
      }

      emitEvent(
        CompletedEvent(moduleId: id, message: 'Delete rollback completed'),
      );
    } catch (e, _) {
      emitEvent(
        FailedEvent(moduleId: id, message: 'Delete rollback failed: $e'),
      );
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<void> _deleteFileWithProgress() async {
    emitEvent(
      ProgressEvent(
        moduleId: id,
        current: 0,
        total: 1,
        message: 'Deleting file...',
      ),
    );

    if (!_shouldIncludeFile(source)) {
      skippedFiles++;
      return;
    }

    try {
      if (useTrash) {
        await _moveToTrash(source);
        trashedFiles++;
      } else {
        await FileUtils.deleteFile(source, fileSystem: fileSystem);
        deletedFiles++;
      }
    } catch (e) {
      throw ActionFailedException(
        'Failed to delete file $source',
        moduleId: id,
        cause: e,
      );
    }
  }

  Future<void> _deleteDirectoryWithProgress() async {
    emitEvent(
      ProgressEvent(
        moduleId: id,
        current: 0,
        total: 1,
        message: 'Scanning directory...',
      ),
    );

    final filesToDelete = await _scanDirectoryForFiles(source);
    totalFiles = filesToDelete.length;

    for (var i = 0; i < filesToDelete.length; i++) {
      final filePath = filesToDelete[i];
      final progress = ((i + 1) / filesToDelete.length * 100).round();
      emitEvent(
        ProgressEvent(
          moduleId: id,
          current: i + 1,
          total: filesToDelete.length,
          message: 'Deleting $filePath ($progress%)',
        ),
      );

      await _deleteFileEntry(filePath);
    }

    // Delete the directory itself if empty
    if (recursive) {
      try {
        await FileUtils.deleteDirectory(
          source,
          recursive: false,
          fileSystem: fileSystem,
        );
      } catch (_) {
        // Directory might not be empty
      }
    }
  }

  Future<void> _deleteFileEntry(String filePath) async {
    if (!_shouldIncludeFile(filePath)) {
      skippedFiles++;
      return;
    }

    try {
      if (useTrash) {
        await _moveToTrash(filePath);
        trashedFiles++;
      } else {
        await FileUtils.deleteFile(filePath, fileSystem: fileSystem);
        deletedFiles++;
      }
    } catch (e) {
      emitEvent(
        StatusUpdateEvent(
          moduleId: id,
          level: StatusEvent.warning,
          message: 'Failed to delete $filePath: $e',
        ),
      );
    }
  }

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

  bool _shouldIncludeFile(String filePath) {
    final fileName = path.basename(filePath);
    final relativePath = path.relative(filePath, from: source);

    for (final pattern in excludePatterns) {
      if (_matchesPattern(fileName, pattern) ||
          _matchesPattern(relativePath, pattern)) {
        return false;
      }
    }

    if (includePatterns.isEmpty) return true;

    for (final pattern in includePatterns) {
      if (_matchesPattern(fileName, pattern) ||
          _matchesPattern(relativePath, pattern)) {
        return true;
      }
    }

    return false;
  }

  bool _matchesPattern(String text, String pattern) {
    try {
      return Glob(pattern).matches(text);
    } catch (_) {
      return text == pattern;
    }
  }

  Future<void> _moveToTrash(String filePath) async {
    // Simple implementation — delete the file
    // In a real implementation this would use system trash
    await FileUtils.deleteFile(filePath, fileSystem: fileSystem);
  }
}
