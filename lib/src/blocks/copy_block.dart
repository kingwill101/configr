import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:file/file.dart' show File;
import 'package:glob/glob.dart';
import 'package:i3config/i3config_v2.dart' as i3;
import 'package:path/path.dart' as path;
import 'package:configr/src/utils/fs.dart' show resolveHomeDirectory;

/// Block handler for the `copy` config action.
///
/// Registered with `blockType: 'copy'` so the i3config v2 state machine
/// dispatches `copy { … }` blocks to this handler.
///
/// Properties using `=` syntax (e.g. `source = "/tmp/foo"`) are automatically
/// handled by the processor's built-in assignment handler — they do NOT need
/// individual command handlers here. Only **command-style** properties
/// (e.g. `include "*.dart"` without `=`) are registered via
/// [registerScopedCommands].
class CopyBlock extends ActionBlock {
  @override
  String get blockType => 'copy';

  // ---------------------------------------------------------------------------
  // Copy-specific properties
  // ---------------------------------------------------------------------------

  List<String> includePatterns = [];
  List<String> excludePatterns = [];
  bool recursive = false;
  String conflictResolution = 'skip';
  bool showProgress = true;

  // ---------------------------------------------------------------------------
  // Execution state
  // ---------------------------------------------------------------------------

  bool hadToCreateDstDir = false;
  bool destinationFileExisted = false;
  String? originalContent;
  String? destinationDir;
  String? sourceHash;
  bool isDirectorySource = false;
  int copiedFiles = 0;
  int totalFiles = 0;
  int skippedFiles = 0;
  int overwrittenFiles = 0;

  CopyBlock();

  // ---------------------------------------------------------------------------
  // Handler pipeline
  // ---------------------------------------------------------------------------

  @override
  Map<String, String> get additionalProperties => {
    if (includePatterns.isNotEmpty) 'include': includePatterns.join(', '),
    if (excludePatterns.isNotEmpty) 'exclude': excludePatterns.join(', '),
    if (conflictResolution != 'skip') 'conflict_resolution': conflictResolution,
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (recursive) 'recursive': recursive,
    if (!showProgress) 'show_progress': showProgress,
  };

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);

    // Read copy-specific properties from context variables.
    // These are set either by:
    //   - Built-in assignment handler:  recursive = true
    //   - Scoped command handlers:       recursive true  (no =)

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

    final recVal = context.getVariable('recursive');
    if (recVal is String) recursive = recVal == 'true';
    if (recVal is bool) recursive = recVal;

    final crVal = context.getVariable('conflict_resolution');
    if (crVal is String) conflictResolution = crVal;

    final spVal = context.getVariable('show_progress');
    if (spVal is String) showProgress = spVal != 'false';
    if (spVal is bool) showProgress = spVal;
  }

  // ---------------------------------------------------------------------------
  // Execution
  // ---------------------------------------------------------------------------

  @override
  String dryRunSummary() {
    if (renderedContent != null && !sourceWasExplicitlySet) {
      return '$blockType: [rendered template] → $destination';
    }
    if (recursive) {
      return '$blockType: $source/ → $destination/ (recursive)';
    }
    if (source.isNotEmpty && destination.isNotEmpty) {
      return '$blockType: $source → $destination';
    }
    return super.dryRunSummary();
  }

  @override
  Future<void> execute() async {
    // If rendered content is available from a parent template and source
    // wasn't explicitly set, write the rendered string instead of copying
    // from a source file.
    if (renderedContent != null && !sourceWasExplicitlySet) {
      await _writeRenderedContent();
      return;
    }

    emitEvent(
      StartedEvent(
        moduleId: id,
        message: 'Starting copy of $source to $destination',
      ),
    );

    source = resolveHomeDirectory(source);
    destination = resolveHomeDirectory(destination);

    final existCheck = await fileService.pathExists(source);
    if (!existCheck.exists) {
      throw SourceNotFoundException(source);
    }

    isDirectorySource = existCheck.isDir;

    // Execute child action blocks
    for (final child in children) {
      await child.execute();
    }

    destinationDir = isDirectorySource
        ? destination
        : path.dirname(destination);

    if (!await fileService.directoryExists(destinationDir!)) {
      logger.info('Creating directory $destinationDir');
      await fileService.createDirectory(destinationDir!);
      hadToCreateDstDir = true;
    }

    final exists = await (isDirectorySource
        ? fileService.directoryExists(destination)
        : fileService.fileExists(destination));

    try {
      if (exists) {
        final content = await fileService.readFile(destination);
        originalContent = content;
        destinationFileExisted = true;
      }

      sourceHash = await fileService.computeFileHash(source);
    } catch (e, st) {
      logger.warning('Failed to read state for copy', e, st);
    }

    try {
      if (isDirectorySource) {
        await _copyDirectoryWithProgress();
      } else {
        await _copyFileWithProgress();
      }

      emitEvent(
        CompletedEvent(
          moduleId: id,
          message:
              'Copy completed — $copiedFiles copied, $skippedFiles skipped, $overwrittenFiles overwritten',
        ),
      );
    } catch (e, _) {
      emitEvent(FailedEvent(moduleId: id, message: 'Copy failed: $e'));
      throw ActionFailedException(
        'Failed to copy $source → $destination',
        cause: e,
        moduleId: id,
      );
    }

    status = 'completed';
  }

  @override
  Future<void> rollback() async {
    emitEvent(
      StartedEvent(
        moduleId: id,
        message: 'Rolling back copy of $source → $destination',
      ),
    );

    try {
      if (isDirectorySource) {
        if (await fileService.directoryExists(destination)) {
          await fileService.deleteDirectory(destination, recursive: true);
        }
      } else {
        if (await fileService.fileExists(destination)) {
          if (!destinationFileExisted) {
            await fileService.deleteFile(destination);
          } else if (originalContent != null) {
            await fileService.writeFile(destination, originalContent!);
          }
        }

        if (hadToCreateDstDir && destinationDir != null) {
          if (await fileService.directoryExists(destinationDir!)) {
            final dir = fileSystem.directory(destinationDir);
            final contents = await dir.list().toList();
            if (contents.isEmpty) {
              await fileService.deleteDirectory(
                destinationDir!,
                recursive: true,
              );
            }
          }
        }
      }

      for (final child in children) {
        await child.rollback();
      }

      emitEvent(
        CompletedEvent(moduleId: id, message: 'Copy rollback completed'),
      );
    } catch (e, _) {
      emitEvent(FailedEvent(moduleId: id, message: 'Copy rollback failed: $e'));
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Write rendered template content to destination instead of copying a file.
  Future<void> _writeRenderedContent() async {
    emitEvent(
      StartedEvent(
        moduleId: id,
        message: 'Copying rendered template content to $destination',
      ),
    );
    destination = resolveHomeDirectory(destination);

    final destDir = path.dirname(destination);
    if (!await fileService.directoryExists(destDir)) {
      await fileService.createDirectory(destDir);
      hadToCreateDstDir = true;
      destinationDir = destDir;
    }

    // Track original content for rollback
    final existsResult = await fileService.pathExists(destination);
    if (existsResult.exists) {
      destinationFileExisted = true;
      try {
        final content = await fileService.readFile(destination);
        originalContent = content;
      } catch (e, st) {
        logger.warning('Failed to read original content for rollback', e, st);
      }
    }

    try {
      await fileService.writeFile(destination, renderedContent!);
      copiedFiles = 1;

      emitEvent(
        CompletedEvent(
          moduleId: id,
          message: 'Copy completed — wrote rendered template content',
        ),
      );
    } catch (e, _) {
      emitEvent(FailedEvent(moduleId: id, message: 'Copy failed: $e'));
      throw ActionFailedException(
        'Failed to copy rendered content to $destination',
        cause: e,
        moduleId: id,
      );
    }

    status = 'completed';
  }

  Future<void> _copyFileWithProgress() async {
    emitEvent(
      StatusUpdateEvent(
        moduleId: id,
        level: StatusEvent.info,
        message: 'Copying file…',
      ),
    );

    if (!_shouldIncludeFile(source)) {
      skippedFiles++;
      return;
    }

    final destExists = await fileService.fileExists(destination);
    if (destExists) {
      switch (conflictResolution) {
        case 'skip':
          skippedFiles++;
          return;
        case 'overwrite':
        case 'merge':
          overwrittenFiles++;
          break;
      }
    }

    await fileService.copyFile(source, destination);
    copiedFiles++;
  }

  Future<void> _copyDirectoryWithProgress() async {
    emitEvent(
      StatusUpdateEvent(
        moduleId: id,
        level: StatusEvent.info,
        message: 'Scanning directory…',
      ),
    );

    final filesToCopy = await _scanDirectory(source);
    totalFiles = filesToCopy.length;

    for (var i = 0; i < filesToCopy.length; i++) {
      final filePath = filesToCopy[i];
      final relativePath = path.relative(filePath, from: source);
      final destPath = path.join(destination, relativePath);

      if (showProgress) {
        final progress = ((i + 1) / filesToCopy.length * 100).round();
        emitEvent(
          ProgressEvent(
            moduleId: id,
            current: i + 1,
            total: filesToCopy.length,
            message: 'Copying $relativePath ($progress%)',
          ),
        );
      }

      final destDir = path.dirname(destPath);
      if (!await fileService.directoryExists(destDir)) {
        await fileService.createDirectory(destDir);
      }

      await _copyFileEntry(filePath, destPath);
    }
  }

  Future<void> _copyFileEntry(String src, String dst) async {
    if (!_shouldIncludeFile(src)) {
      skippedFiles++;
      return;
    }

    final exists = await fileService.fileExists(dst);
    if (exists) {
      switch (conflictResolution) {
        case 'skip':
          skippedFiles++;
          return;
        case 'overwrite':
        case 'merge':
          overwrittenFiles++;
          break;
      }
    }

    await fileService.copyFile(src, dst);
    copiedFiles++;
  }

  Future<List<String>> _scanDirectory(String dirPath) async {
    final files = <String>[];
    final dir = fileSystem.directory(dirPath);
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
      if (_matches(fileName, pattern) || _matches(relativePath, pattern)) {
        return false;
      }
    }

    if (includePatterns.isEmpty) return true;

    for (final pattern in includePatterns) {
      if (_matches(fileName, pattern) || _matches(relativePath, pattern)) {
        return true;
      }
    }

    return false;
  }

  bool _matches(String text, String pattern) {
    try {
      return Glob(pattern).matches(text);
    } catch (_) {
      return text == pattern;
    }
  }
}
