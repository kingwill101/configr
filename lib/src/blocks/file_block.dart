import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/models/v2_lockfile_data.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:i3config/i3config_v2.dart' as i3;

/// Block handler for the `file` config action.
///
/// Creates, edits (append/prepend/replace), or removes files with backup
/// and full rollback support.
///
/// ```i3
/// file {
///   source = "/path/to/file"
///   content = "file contents"
///   operation = "create"         # create | edit | remove
///   edit_mode = "replace"        # replace | append | prepend
///   create_directories = true
///   backup_original = true
/// }
/// ```
class FileBlock extends ActionBlock {
  @override
  String get blockType => 'file';

  // ---------------------------------------------------------------------------
  // File-specific properties
  // ---------------------------------------------------------------------------

  String operation = 'create';
  String content = '';
  String filePath = '';
  String editMode = 'replace';
  bool createDirectories = true;
  bool backupOriginal = false;
  String backupSuffix = '.backup';

  // ---------------------------------------------------------------------------
  // Execution state
  // ---------------------------------------------------------------------------

  bool fileExisted = false;
  String? originalContent;
  String? backupPath;
  bool operationSuccess = false;

  FileBlock();

  // ---------------------------------------------------------------------------
  // Handler pipeline
  // ---------------------------------------------------------------------------

  @override
  Map<String, String> get additionalProperties => {
    if (content.isNotEmpty) 'content': content,
    if (operation != 'create') 'operation': operation,
    if (editMode != 'replace') 'edit_mode': editMode,
    if (filePath != source && filePath.isNotEmpty) 'file_path': filePath,
    if (backupSuffix != '.backup') 'backup_suffix': backupSuffix,
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (!createDirectories) 'create_directories': createDirectories,
    if (backupOriginal) 'backup_original': backupOriginal,
  };

  @override
  Map<String, dynamic>? get lockfileMetadata => {
    if (delegateTo != null) 'delegate_to': delegateTo,
    if (filePath.isNotEmpty) 'file_path': filePath,
    'operation': operation,
    if (content.isNotEmpty) 'content': content,
    if (editMode != 'replace') 'edit_mode': editMode,
    if (!createDirectories) 'create_directories': createDirectories,
    if (backupOriginal) 'backup_original': backupOriginal,
    if (backupSuffix != '.backup') 'backup_suffix': backupSuffix,
    'operation_success': operationSuccess,
    'file_existed': fileExisted,
    if (originalContent != null) 'original_content': originalContent,
    if (backupPath != null) 'backup_path': backupPath,
  };

  @override
  void restoreFromRecord(AppliedBlockRecord record) {
    super.restoreFromRecord(record);
    filePath = record.metadata?['file_path'] as String? ?? source;
    operation = record.metadata?['operation'] as String? ?? 'create';
    content = record.metadata?['content'] as String? ?? '';
    editMode = record.metadata?['edit_mode'] as String? ?? 'replace';
    createDirectories = record.metadata?['create_directories'] as bool? ?? true;
    backupOriginal = record.metadata?['backup_original'] as bool? ?? false;
    backupSuffix = record.metadata?['backup_suffix'] as String? ?? '.backup';
    operationSuccess = record.metadata?['operation_success'] as bool? ?? true;
    fileExisted = record.metadata?['file_existed'] as bool? ?? false;
    originalContent = record.metadata?['original_content'] as String?;
    backupPath = record.metadata?['backup_path'] as String?;
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);

    content = (context.getVariable('content') as String?) ?? '';
    operation = (context.getVariable('operation') as String?) ?? 'create';
    editMode = (context.getVariable('edit_mode') as String?) ?? 'replace';

    // file_path can be explicit or fall back to source
    filePath = (context.getVariable('file_path') as String?) ?? source;

    createDirectories = switch (context.getVariable('create_directories')) {
      false || 'false' => false,
      _ => true,
    };

    backupOriginal = switch (context.getVariable('backup_original')) {
      true || 'true' => true,
      _ => false,
    };

    backupSuffix =
        (context.getVariable('backup_suffix') as String?) ?? '.backup';
  }

  // ---------------------------------------------------------------------------
  // Execution
  // ---------------------------------------------------------------------------

  @override
  String dryRunSummary() {
    if (source.isNotEmpty) {
      final size = content.length;
      return '$blockType: $source ($size bytes)';
    }
    return super.dryRunSummary();
  }

  @override
  Future<void> execute() async {
    emitEvent(
      StartedEvent(
        moduleId: id,
        message: 'Starting file $operation operation on $filePath',
      ),
    );

    if (filePath.isEmpty) {
      throw ActionFailedException(
        'File path is required for $operation operation',
        moduleId: id,
      );
    }

    try {
      switch (operation) {
        case 'create':
          await _executeCreate();
          break;
        case 'edit':
          await _executeEdit();
          break;
        case 'remove':
          await _executeRemove();
          break;
        default:
          throw ActionFailedException(
            'Unknown file operation: $operation',
            moduleId: id,
          );
      }

      operationSuccess = true;
      emitEvent(
        CompletedEvent(
          moduleId: id,
          message: 'File $operation completed on $filePath',
        ),
      );
    } catch (e, _) {
      operationSuccess = false;
      emitEvent(
        FailedEvent(moduleId: id, message: 'File $operation failed: $e'),
      );
      throw ActionFailedException(
        'File $operation failed on $filePath',
        cause: e,
        moduleId: id,
      );
    }

    status = 'completed';
  }

  @override
  Future<void> rollback() async {
    if (!operationSuccess) return;

    emitEvent(
      StatusUpdateEvent(
        moduleId: id,
        level: StatusEvent.info,
        message: 'Rolling back file $operation operation',
      ),
    );

    try {
      switch (operation) {
        case 'create':
          await _rollbackCreate();
          break;
        case 'edit':
          await _rollbackEdit();
          break;
        case 'remove':
          await _rollbackRemove();
          break;
      }

      emitEvent(
        StatusUpdateEvent(
          moduleId: id,
          level: StatusEvent.info,
          message: 'File rollback completed',
        ),
      );
    } catch (e, _) {
      emitEvent(
        StatusUpdateEvent(
          moduleId: id,
          level: StatusEvent.error,
          message: 'File rollback failed: $e',
        ),
      );
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Create implementation
  // ---------------------------------------------------------------------------

  Future<void> _executeCreate() async {
    fileExisted = await fileService.fileExists(filePath);

    // Create parent directories if needed
    if (createDirectories) {
      final dir = fileSystem.file(filePath).parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }

    // Backup original if it exists
    if (fileExisted && backupOriginal) {
      backupPath = '$filePath$backupSuffix';
      await fileService.copyFile(filePath, backupPath!);
    }

    // Store original content for rollback
    if (fileExisted) {
      originalContent = await fileService.readFile(filePath);
    }

    // Write content
    await fileService.writeFile(filePath, content);
  }

  // ---------------------------------------------------------------------------
  // Edit implementation
  // ---------------------------------------------------------------------------

  Future<void> _executeEdit() async {
    final exists = await fileService.fileExists(filePath);
    if (!exists) {
      throw ActionFailedException(
        'File does not exist for edit operation: $filePath',
        moduleId: id,
      );
    }

    fileExisted = true;
    originalContent = await fileService.readFile(filePath);

    // Backup if enabled
    if (backupOriginal) {
      backupPath = '$filePath$backupSuffix';
      await fileService.copyFile(filePath, backupPath!);
    }

    String newContent;
    switch (editMode) {
      case 'replace':
        newContent = content;
        break;
      case 'append':
        newContent = originalContent! + content;
        break;
      case 'prepend':
        newContent = content + originalContent!;
        break;
      default:
        throw ActionFailedException(
          'Unknown edit mode: $editMode',
          moduleId: id,
        );
    }

    await fileService.writeFile(filePath, newContent);
  }

  // ---------------------------------------------------------------------------
  // Remove implementation
  // ---------------------------------------------------------------------------

  Future<void> _executeRemove() async {
    fileExisted = await fileService.fileExists(filePath);

    if (!fileExisted) {
      logger.info('File does not exist, nothing to remove: $filePath');
      return;
    }

    // Store original content for rollback
    originalContent = await fileService.readFile(filePath);

    // Backup if enabled
    if (backupOriginal) {
      backupPath = '$filePath$backupSuffix';
      await fileService.copyFile(filePath, backupPath!);
    }

    // Remove file
    await fileService.deleteFile(filePath);
  }

  // ---------------------------------------------------------------------------
  // Rollback helpers
  // ---------------------------------------------------------------------------

  Future<void> _rollbackCreate() async {
    if (fileExisted && originalContent != null) {
      await fileService.writeFile(filePath, originalContent!);
    } else if (await fileService.fileExists(filePath)) {
      await fileService.deleteFile(filePath);
    }

    if (backupPath != null && await fileService.fileExists(backupPath!)) {
      await fileService.deleteFile(backupPath!);
    }
  }

  Future<void> _rollbackEdit() async {
    if (originalContent != null) {
      await fileService.writeFile(filePath, originalContent!);
    }

    if (backupPath != null && await fileService.fileExists(backupPath!)) {
      await fileService.deleteFile(backupPath!);
    }
  }

  Future<void> _rollbackRemove() async {
    if (originalContent != null) {
      await fileService.writeFile(filePath, originalContent!);
    } else if (backupPath != null &&
        await fileService.fileExists(backupPath!)) {
      final content = await fileService.readFile(backupPath!);
      await fileService.writeFile(filePath, content);
    }

    if (backupPath != null && await fileService.fileExists(backupPath!)) {
      await fileService.deleteFile(backupPath!);
    }
  }
}
