import 'dart:io';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/modules/resource/resource_module.dart';
import 'package:configr/src/utils/logging.dart';

/// File resource module for creating, editing, and removing files.
/// 
/// Features:
/// - Create files with content
/// - Edit existing files (append, prepend, replace)
/// - Remove files
/// - Backup and restore functionality
/// - Content validation
/// - Rollback support
class FileFileModule extends ResourceModule {
  // State getters
  String get operation => state['operation'] as String? ?? 'create';
  String get content => state['content'] as String? ?? '';
  String get filePath => state['filePath'] as String? ?? '';
  String get source => state['source'] as String? ?? '';
  String get destination => state['destination'] as String? ?? '';
  bool get createDirectories => state['createDirectories'] as bool? ?? true;
  bool get backupOriginal => _parseBool(state['backupOriginal']);
  String get backupSuffix => state['backupSuffix'] as String? ?? '.backup';
  String get editMode => state['editMode'] as String? ?? 'replace'; // replace, append, prepend
  String? get originalContent => state['originalContent'] as String?;
  String? get backupPath => state['backupPath'] as String?;
  bool get fileExisted => state['fileExisted'] as bool? ?? false;
  bool get operationSuccess => state['operationSuccess'] as bool? ?? false;

  FileFileModule(super.file, super.action,
      {super.allowedActions = const ['file'], super.fileSystem, super.eventBus}) {
    // Only initialize default state if no state exists (i.e., not during rollback)
    if (action.state.isEmpty) {
      updateState({
        'operation': 'create',
        'content': '',
        'filePath': '',
        'source': file.source,
        'destination': file.destination,
        'createDirectories': true,
        'backupOriginal': false,
        'backupSuffix': '.backup',
        'editMode': 'replace',
        'originalContent': null,
        'backupPath': null,
        'fileExisted': false,
        'operationSuccess': false,
      });
    }
  }

  bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  @override
  Future<void> execute() async {
    // Parse configuration from action properties
    final operation = action.properties['operation'] as String? ?? 'create';
    final content = action.properties['content'] as String? ?? '';
    
    // Use destination as primary path, with file_path as fallback for backward compatibility
    final filePath = action.properties['file_path'] as String? ?? 
                    action.properties['filePath'] as String? ?? 
                    file.destination;
    final source = file.source;
    final destination = file.destination;
    
    final createDirectories = _parseBool(action.properties['create_directories']) ||
                             _parseBool(action.properties['createDirectories']);
    final backupOriginal = _parseBool(action.properties['backup_original']) ||
                          _parseBool(action.properties['backupOriginal']);
    final backupSuffix = action.properties['backup_suffix'] as String? ?? 
                        action.properties['backupSuffix'] as String? ?? '.backup';
    final editMode = action.properties['edit_mode'] as String? ?? 
                    action.properties['editMode'] as String? ?? 'replace';

    // Update state with parsed configuration
    updateState({
      'operation': operation,
      'content': content,
      'filePath': filePath,
      'source': source,
      'destination': destination,
      'createDirectories': createDirectories,
      'backupOriginal': backupOriginal,
      'backupSuffix': backupSuffix,
      'editMode': editMode,
    });

    emitEvent(StartedEvent(moduleId: action.id, message: 'Starting file $operation operation'));

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
          throw ActionFailedException('Unknown file operation: $operation', moduleId: action.id);
      }

      updateState({'operationSuccess': true});
      await saveState();
      emitEvent(CompletedEvent(moduleId: action.id, message: 'File $operation operation completed successfully'));
    } catch (e) {
      updateState({'operationSuccess': false});
      await saveState();
      emitEvent(FailedEvent(moduleId: action.id, message: 'File $operation operation failed: $e'));
      rethrow;
    }
  }

  Future<void> _executeCreate() async {
    if (filePath.isEmpty) {
      throw ActionFailedException('File path is required for create operation', moduleId: action.id);
    }

    final file = File(filePath);
    final directory = file.parent;
    
    // Check if file already exists
    final fileExisted = file.existsSync();
    updateState({'fileExisted': fileExisted});

    if (fileExisted) {
      logger.info('File already exists: $filePath');
      // For create operation, we might want to overwrite or skip
      // For now, we'll overwrite
    }

    // Create directories if needed
    if (createDirectories && !directory.existsSync()) {
      logger.info('Creating directory: ${directory.path}');
      directory.createSync(recursive: true);
    }

    // Backup original file if it exists and backup is enabled
    if (fileExisted && backupOriginal) {
      final backupFile = File('$filePath$backupSuffix');
      await file.copy(backupFile.path);
      updateState({'backupPath': backupFile.path});
      logger.info('Backed up original file to: ${backupFile.path}');
    }

    // Store original content for rollback
    String? originalContent;
    if (fileExisted) {
      originalContent = await file.readAsString();
      updateState({'originalContent': originalContent});
    }

    // Write content to file
    emitEvent(StatusUpdateEvent(moduleId: action.id, message: 'Creating file: $filePath', level: StatusEvent.info));
    await file.writeAsString(content);
    
    logger.info('File created successfully: $filePath');
  }

  Future<void> _executeEdit() async {
    if (filePath.isEmpty) {
      throw ActionFailedException('File path is required for edit operation', moduleId: action.id);
    }

    final file = File(filePath);
    
    if (!file.existsSync()) {
      throw ActionFailedException('File does not exist for edit operation: $filePath', moduleId: action.id);
    }

    // Read original content
    final originalContent = await file.readAsString();
    updateState({
      'fileExisted': true,
      'originalContent': originalContent,
    });

    // Backup original file if backup is enabled
    if (backupOriginal) {
      final backupFile = File('$filePath$backupSuffix');
      await file.copy(backupFile.path);
      updateState({'backupPath': backupFile.path});
      logger.info('Backed up original file to: ${backupFile.path}');
    }

    // Apply edit based on mode
    String newContent;
    switch (editMode) {
      case 'replace':
        newContent = content;
        break;
      case 'append':
        newContent = originalContent + content;
        break;
      case 'prepend':
        newContent = content + originalContent;
        break;
      default:
        throw ActionFailedException('Unknown edit mode: $editMode', moduleId: action.id);
    }

    // Write new content
    emitEvent(StatusUpdateEvent(moduleId: action.id, message: 'Editing file: $filePath (mode: $editMode)', level: StatusEvent.info));
    await file.writeAsString(newContent);
    
    logger.info('File edited successfully: $filePath');
  }

  Future<void> _executeRemove() async {
    if (filePath.isEmpty) {
      throw ActionFailedException('File path is required for remove operation', moduleId: action.id);
    }

    final file = File(filePath);
    
    if (!file.existsSync()) {
      logger.info('File does not exist, nothing to remove: $filePath');
      updateState({
        'fileExisted': false,
        'operationSuccess': true,
      });
      return;
    }

    // Read original content for rollback
    final originalContent = await file.readAsString();
    updateState({
      'fileExisted': true,
      'originalContent': originalContent,
    });

    // Backup file if backup is enabled
    if (backupOriginal) {
      final backupFile = File('$filePath$backupSuffix');
      await file.copy(backupFile.path);
      updateState({'backupPath': backupFile.path});
      logger.info('Backed up file before removal to: ${backupFile.path}');
    }

    // Remove file
    emitEvent(StatusUpdateEvent(moduleId: action.id, message: 'Removing file: $filePath', level: StatusEvent.info));
    await file.delete();
    
    logger.info('File removed successfully: $filePath');
  }

  @override
  Future<void> rollback() async {
    final operation = state['operation'] as String? ?? 'create';
    final operationSuccess = state['operationSuccess'] as bool? ?? false;
    
    if (!operationSuccess) {
      logger.info('Operation was not successful, skipping rollback');
      return;
    }

    emitEvent(StatusUpdateEvent(moduleId: action.id, message: 'Rolling back file $operation operation', level: StatusEvent.info));

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
        default:
          logger.warning('Unknown operation for rollback: $operation');
      }

      emitEvent(StatusUpdateEvent(moduleId: action.id, message: 'File rollback completed', level: StatusEvent.info));
    } catch (e) {
      emitEvent(StatusUpdateEvent(moduleId: action.id, message: 'File rollback failed: $e', level: StatusEvent.error));
      logger.severe('File rollback failed: $e');
    }
  }

  Future<void> _rollbackCreate() async {
    final filePath = state['filePath'] as String? ?? '';
    final fileExisted = state['fileExisted'] as bool? ?? false;
    final originalContent = state['originalContent'] as String?;
    final backupPath = state['backupPath'] as String?;

    if (filePath.isEmpty) return;

    final file = File(filePath);
    
    if (fileExisted && originalContent != null) {
      // Restore original content
      await file.writeAsString(originalContent);
      logger.info('Restored original content to: $filePath');
    } else if (!fileExisted) {
      // Remove the file we created
      if (file.existsSync()) {
        await file.delete();
        logger.info('Removed created file: $filePath');
      }
    }

    // Remove backup file if it exists
    if (backupPath != null) {
      final backupFile = File(backupPath);
      if (backupFile.existsSync()) {
        await backupFile.delete();
        logger.info('Removed backup file: $backupPath');
      }
    }
  }

  Future<void> _rollbackEdit() async {
    final filePath = state['filePath'] as String? ?? '';
    final originalContent = state['originalContent'] as String?;
    final backupPath = state['backupPath'] as String?;

    if (filePath.isEmpty || originalContent == null) return;

    final file = File(filePath);
    
    // Restore original content
    await file.writeAsString(originalContent);
    logger.info('Restored original content to: $filePath');

    // Remove backup file if it exists
    if (backupPath != null) {
      final backupFile = File(backupPath);
      if (backupFile.existsSync()) {
        await backupFile.delete();
        logger.info('Removed backup file: $backupPath');
      }
    }
  }

  Future<void> _rollbackRemove() async {
    final filePath = state['filePath'] as String? ?? '';
    final originalContent = state['originalContent'] as String?;
    final backupPath = state['backupPath'] as String?;

    if (filePath.isEmpty) return;

    final file = File(filePath);
    
    if (originalContent != null) {
      // Recreate the file with original content
      await file.writeAsString(originalContent);
      logger.info('Recreated removed file: $filePath');
    } else if (backupPath != null) {
      // Restore from backup
      final backupFile = File(backupPath);
      if (backupFile.existsSync()) {
        await backupFile.copy(filePath);
        logger.info('Restored file from backup: $filePath');
      }
    }

    // Remove backup file if it exists
    if (backupPath != null) {
      final backupFile = File(backupPath);
      if (backupFile.existsSync()) {
        await backupFile.delete();
        logger.info('Removed backup file: $backupPath');
      }
    }
  }
}
