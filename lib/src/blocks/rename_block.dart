import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/file_utils.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:i3config/i3config_v2.dart' as i3;
import 'package:path/path.dart' as path;

/// Block handler for the `rename` config action.
///
/// Renames a file from [source] to [destination].
///
/// ```i3
/// rename {
///   source = "/path/to/old_name"
///   destination = "/path/to/new_name"
///   overwrite = true
/// }
/// ```
class RenameBlock extends ActionBlock {
  @override
  String get blockType => 'rename';

  bool overwrite = false;

  // Rollback state
  String? originalName;
  bool destinationFileExisted = false;
  bool didRename = false;

  RenameBlock();

  @override
  Map<String, String> get additionalProperties => const {};

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (overwrite) 'overwrite': overwrite,
  };

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);

    overwrite = switch (context.getVariable('overwrite')) {
      true || 'true' => true,
      _ => false,
    };
  }

  @override
  Future<void> execute() async {
    emitEvent(
      StartedEvent(
        moduleId: id,
        message: 'Starting rename of $source → $destination',
      ),
    );

    if (!await FileUtils.fileExists(source, fileSystem: fileSystem)) {
      logger.severe('Source file $source does not exist');
      throw SourceNotFoundException(source);
    }

    final exists = await FileUtils.fileExists(
      destination,
      fileSystem: fileSystem,
    );
    destinationFileExisted = exists;

    if (exists) {
      emitEvent(
        StatusUpdateEvent(
          moduleId: id,
          level: StatusEvent.warning,
          message: 'Destination already exists: $destination',
        ),
      );
      if (!overwrite) {
        logger.severe(
          'Destination $destination already exists and overwrite is not allowed',
        );
        throw DestinationExistsException(destination);
      }
    }

    originalName = path.basename(source);
    logger.info('Renaming $source → $destination');
    try {
      await FileUtils.moveFile(source, destination, fileSystem: fileSystem);
      didRename = true;
      emitEvent(
        CompletedEvent(
          moduleId: id,
          message: 'Rename completed: $source → $destination',
        ),
      );
    } catch (e, st) {
      emitEvent(FailedEvent(moduleId: id, message: 'Rename failed: $e'));
      throw ActionFailedException(
        'Failed to rename $source → $destination',
        moduleId: id,
        cause: e,
        stackTrace: st,
      );
    }

    status = 'completed';
  }

  @override
  Future<void> rollback() async {
    if (!didRename || originalName == null) return;

    emitEvent(
      StartedEvent(
        moduleId: id,
        message: 'Rolling back rename of $destination',
      ),
    );

    try {
      final originalPath = path.join(path.dirname(source), originalName!);
      logger.info('Renaming back: $destination → $originalPath');
      await FileUtils.moveFile(
        destination,
        originalPath,
        fileSystem: fileSystem,
      );
      emitEvent(
        CompletedEvent(moduleId: id, message: 'Rename rollback completed'),
      );
    } catch (e) {
      emitEvent(
        FailedEvent(moduleId: id, message: 'Rename rollback failed: $e'),
      );
      rethrow;
    }
  }
}
