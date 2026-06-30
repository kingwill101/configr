import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:i3config/i3config_v2.dart' as i3;
import 'package:path/path.dart' as path;

/// Block handler for the `move` config action.
///
/// Moves a file from [source] to [destination], creating the destination
/// directory if needed.
///
/// ```i3
/// move {
///   source = "/path/to/source"
///   destination = "/path/to/destination"
///   overwrite = true
/// }
/// ```
class MoveBlock extends ActionBlock {
  @override
  String get blockType => 'move';

  bool overwrite = false;

  // Rollback state
  bool hadToCreateDstDir = false;
  bool destinationFileExisted = false;
  String? originalPath;

  MoveBlock();

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
  String dryRunSummary() {
    if (source.isNotEmpty && destination.isNotEmpty) {
      return '$blockType: $source → $destination';
    }
    return super.dryRunSummary();
  }

  @override
  Future<void> execute() async {
    emitEvent(
      StartedEvent(
        moduleId: id,
        message: 'Starting move of $source → $destination',
      ),
    );

    if (!await fileService.fileExists(source)) {
      throw SourceNotFoundException(source);
    }

    final destinationDir = path.dirname(destination);

    if (!await fileService.directoryExists(destinationDir)) {
      logger.info('Creating directory $destinationDir');
      try {
        await fileService.createDirectory(destinationDir);
        hadToCreateDstDir = true;
      } catch (e, st) {
        throw ActionFailedException(
          'Failed to create destination directory $destinationDir',
          moduleId: id,
          cause: e,
          stackTrace: st,
        );
      }
    }

    final exists = await fileService.fileExists(destination);
    destinationFileExisted = exists;
    originalPath = source;

    if (exists && !overwrite) {
      logger.error(
        'Destination $destination already exists and overwrite is not allowed',
      );
      throw DestinationExistsException(destination);
    }

    logger.info('Moving $source → $destination');
    try {
      await fileService.moveFile(source, destination);
      emitEvent(
        CompletedEvent(
          moduleId: id,
          message: 'Move completed: $source → $destination',
        ),
      );
    } catch (e, st) {
      emitEvent(FailedEvent(moduleId: id, message: 'Move failed: $e'));
      throw ActionFailedException(
        'Failed to move $source → $destination',
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
      StartedEvent(moduleId: id, message: 'Rolling back move of $destination'),
    );

    try {
      if (originalPath != null) {
        logger.info('Moving back: $destination → $originalPath');
        await fileService.moveFile(destination, originalPath!);
      }

      if (hadToCreateDstDir) {
        final destinationDir = path.dirname(destination);
        if (await fileService.directoryExists(destinationDir)) {
          logger.info('Deleting created directory $destinationDir');
          await fileService.deleteDirectory(destinationDir, recursive: true);
        }
      }

      emitEvent(
        CompletedEvent(moduleId: id, message: 'Move rollback completed'),
      );
    } catch (e) {
      emitEvent(FailedEvent(moduleId: id, message: 'Move rollback failed: $e'));
      rethrow;
    }
  }
}
