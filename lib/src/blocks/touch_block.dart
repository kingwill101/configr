import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/file_utils.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:file/local.dart';
import 'package:i3config/i3config_v2.dart' as i3;

/// Block handler for the `touch` config action.
///
/// Creates or updates the modification timestamp of a file.
///
/// ```i3
/// touch {
///   source = "/path/to/file"
///   create_if_missing = true
/// }
/// ```
class TouchBlock extends ActionBlock {
  @override
  String get blockType => 'touch';

  bool createIfMissing = false;

  // Rollback state
  DateTime? originalModificationTime;
  bool fileCreated = false;

  TouchBlock({super.fileSystem, super.eventBus});

  @override
  Map<String, String> get additionalProperties => const {};

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (!createIfMissing) 'create_if_missing': createIfMissing,
  };

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);

    createIfMissing = switch (context.getVariable('create_if_missing')) {
      true || 'true' => true,
      _ => false,
    };
  }

  @override
  Future<void> execute() async {
    emitEvent(
      StartedEvent(
        moduleId: id,
        message: 'Starting touch operation on $source',
      ),
    );

    final fileExists = await FileUtils.fileExists(
      source,
      fileSystem: fileSystem,
    );

    if (!fileExists && !createIfMissing) {
      logger.severe(
        'File $source does not exist and create_if_missing is false',
      );
      throw SourceNotFoundException(source);
    }

    try {
      if (fileExists) {
        final fs = fileSystem ?? const LocalFileSystem();
        final file = fs.file(source);
        originalModificationTime = await file.lastModified();
      } else {
        emitEvent(
          StatusUpdateEvent(
            moduleId: id,
            level: StatusEvent.info,
            message: 'Creating new file: $source',
          ),
        );
        fileCreated = true;
      }

      final fs = fileSystem ?? const LocalFileSystem();
      final file = fs.file(source);
      await file.create(recursive: true);
      await file.setLastModified(DateTime.now());

      emitEvent(
        StatusUpdateEvent(
          moduleId: id,
          level: StatusEvent.info,
          message: 'Touched file: $source',
        ),
      );
      logger.info('Touched file: $source');
    } catch (e, st) {
      throw ActionFailedException(
        'Error touching file $source',
        moduleId: id,
        cause: e,
        stackTrace: st,
      );
    }

    status = 'completed';
  }

  @override
  Future<void> rollback() async {
    emitEvent(
      StartedEvent(
        moduleId: id,
        message: 'Rolling back touch operation on $source',
      ),
    );

    try {
      if (fileCreated) {
        logger.info('Deleting created file: $source');
        await FileUtils.deleteFile(source, fileSystem: fileSystem);
      } else if (originalModificationTime != null) {
        logger.info('Restoring original modification time for: $source');
        final fs = fileSystem ?? const LocalFileSystem();
        final file = fs.file(source);
        await file.setLastModified(originalModificationTime!);
      }
    } catch (e) {
      emitEvent(
        FailedEvent(moduleId: id, message: 'Touch rollback failed: $e'),
      );
      rethrow;
    }

    emitEvent(
      CompletedEvent(moduleId: id, message: 'Touch rollback completed'),
    );
  }
}
