import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/file_utils.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:file/file.dart' show File;
import 'package:i3config/i3config_v2.dart' as i3;

/// Block handler for the `permissions` config action.
///
/// Changes file/directory ownership and permissions.
///
/// ```i3
/// permissions {
///   source = "/path/to/target"
///   owner = "alice"
///   group = "staff"
///   mode = "755"
///   recursive = true
/// }
/// ```
class PermissionsBlock extends ActionBlock {
  @override
  String get blockType => 'permissions';

  String? owner;
  String? group;
  String? mode;
  bool recursive = false;

  // Rollback state
  Map<String, String>? originalOwnership;
  String? originalPermissions;
  List<Map<String, dynamic>> originalStates = [];

  PermissionsBlock();

  @override
  Map<String, String> get additionalProperties => {
    'owner': ?owner,
    'group': ?group,
    'mode': ?mode,
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (recursive) 'recursive': recursive,
  };

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);

    owner = context.getVariable('owner') as String?;
    group = context.getVariable('group') as String?;
    mode = context.getVariable('mode') as String?;
    recursive = switch (context.getVariable('recursive')) {
      true || 'true' => true,
      _ => false,
    };
  }

  @override
  Future<void> execute() async {
    emitEvent(
      StartedEvent(moduleId: id, message: 'Changing permissions on $source'),
    );

    if (!await FileUtils.fileExists(source, fileSystem: fileSystem)) {
      throw SourceNotFoundException(source);
    }

    try {
      final isDir = await FileUtils.directoryExists(
        source,
        fileSystem: fileSystem,
      );

      if (isDir && recursive) {
        await _processDirectoryRecursively(source);
      } else {
        await _processSingleFile(source);
      }

      emitEvent(
        CompletedEvent(moduleId: id, message: 'Permission changes completed'),
      );
    } catch (e, st) {
      emitEvent(
        FailedEvent(moduleId: id, message: 'Permission changes failed: $e'),
      );
      throw ActionFailedException(
        'Permissions failed for $source',
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
      StartedEvent(moduleId: id, message: 'Rolling back permission changes'),
    );

    try {
      if (recursive && originalStates.isNotEmpty) {
        for (final fileState in originalStates) {
          final path = fileState['path'] as String;
          final origOwn =
              fileState['originalOwnership'] as Map<String, String>?;
          final origPerm = fileState['originalPermissions'] as String?;
          if (origOwn != null) {
            await FileUtils.chown(
              path,
              origOwn['owner'],
              origOwn['group'],
              fileSystem: fileSystem,
            );
          }
          if (origPerm != null) {
            await FileUtils.chmod(path, origPerm, fileSystem: fileSystem);
          }
        }
      } else {
        if (originalOwnership != null) {
          await FileUtils.chown(
            source,
            originalOwnership!['owner'],
            originalOwnership!['group'],
            fileSystem: fileSystem,
          );
        }
        if (originalPermissions != null) {
          await FileUtils.chmod(
            source,
            originalPermissions!,
            fileSystem: fileSystem,
          );
        }
      }

      emitEvent(
        CompletedEvent(moduleId: id, message: 'Permissions rollback completed'),
      );
    } catch (e) {
      emitEvent(
        FailedEvent(moduleId: id, message: 'Permissions rollback failed: $e'),
      );
      rethrow;
    }
  }

  Future<void> _processSingleFile(String filePath) async {
    final currentOwn = await FileUtils.getOwnership(filePath);
    final currentPerm = await FileUtils.getPermissions(filePath);
    originalOwnership = currentOwn;
    originalPermissions = currentPerm;

    await _applyPermissions(filePath, currentOwn, currentPerm);
  }

  Future<void> _processDirectoryRecursively(String dirPath) async {
    final files = <String>[];
    await _collectFiles(dirPath, files);

    for (final filePath in files) {
      try {
        final currentOwn = await FileUtils.getOwnership(filePath);
        final currentPerm = await FileUtils.getPermissions(filePath);
        originalStates.add({
          'path': filePath,
          'originalOwnership': currentOwn,
          'originalPermissions': currentPerm,
        });
        await _applyPermissions(filePath, currentOwn, currentPerm);
      } catch (e) {
        logger.warning('Failed to process $filePath: $e');
      }
    }
  }

  Future<void> _collectFiles(String dirPath, List<String> files) async {
    final dir = fileSystem.directory(dirPath);
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        files.add(entity.path);
      }
    }
  }

  Future<void> _applyPermissions(
    String filePath,
    Map<String, String> currentOwn,
    String currentPerm,
  ) async {
    if (owner != null || group != null) {
      logger.info('Setting ownership on $filePath to $owner:$group');
      await FileUtils.chown(filePath, owner, group, fileSystem: fileSystem);
    }
    if (mode != null) {
      logger.info('Setting permissions on $filePath to $mode');
      await FileUtils.chmod(filePath, mode!, fileSystem: fileSystem);
    }
  }
}
