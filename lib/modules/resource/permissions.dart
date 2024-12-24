import 'package:configr/exceptions.dart'
    show
        SourceNotFoundException,
        PermissionDeniedException,
        ActionFailedException;
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/file_utils.dart';
import 'package:configr/utils/logging.dart';

class FilePermissionModule extends ResourceModule {
  String? owner;
  String? group;
  String? mode;
  Map<String, String>? originalOwnership;
  String? originalPermissions;

  FilePermissionModule(super.file, super.action, {super.fileSystem}) {
    owner = action.properties['owner']?.toString();
    group = action.properties['group']?.toString();
    mode = action.properties['mode']?.toString();

    if (owner == null && group == null && mode == null) {
      throw ArgumentError(
          'At least one of owner, group, or mode must be specified');
    }
  }

  @override
  Future<void> call() async {
    final destinationPath = source;

    if (!await FileUtils.fileExists(destinationPath, fileSystem: fileSystem)) {
      logger.severe('Source path $destinationPath does not exist');
      throw SourceNotFoundException(destinationPath);
    }

    executeModules();
    if (isRollingBack) {
      return;
    }

    // Get current ownership and permissions before changing
    originalOwnership = await FileUtils.getOwnership(destinationPath);
    originalPermissions = await FileUtils.getPermissions(destinationPath);

    // Set file owner and group
    if (owner != null || group != null) {
      logger.info('Setting file ownership on $destinationPath');
      try {
        await FileUtils.chown(destinationPath, owner, group,
            fileSystem: fileSystem, privilegeEscalation: privilegeEscalation);
      } catch (e) {
        throw PermissionDeniedException(destinationPath, e);
      }
    }

    // Set file permissions
    if (mode != null) {
      logger.info('Setting file permissions on $destinationPath to $mode');
      try {
        await FileUtils.chmod(destinationPath, mode!,
            fileSystem: fileSystem, privilegeEscalation: privilegeEscalation);
      } catch (e, stackTrace) {
        throw PermissionDeniedException(destinationPath, e, stackTrace);
      }
    }

    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
    // Verify the changes were applied correctly
    if (owner != null || group != null) {
      final currentOwnership = await FileUtils.getOwnership(destinationPath);

      if (owner != null && currentOwnership['owner'] != owner) {
        throw ActionFailedException(
            'Failed to set owner. Expected: $owner, Got: ${currentOwnership['owner']}');
      }

      if (group != null && currentOwnership['group'] != group) {
        throw ActionFailedException(
            'Failed to set group. Expected: $group, Got: ${currentOwnership['group']}');
      }
    }

    if (mode != null) {
      final currentMode = await FileUtils.getPermissions(destinationPath);
      if (currentMode != mode) {
        throw ActionFailedException(
            'Failed to set permissions. Expected: $mode, Got: $currentMode');
      }
    }
  }

  @override
  Future<void> rollback() async {
    final destinationPath = source;

    // Rollback ownership
    if (originalOwnership != null) {
      logger.info('Restoring original ownership for $destinationPath');
      try {
        await FileUtils.chown(destinationPath, originalOwnership!['owner'],
            originalOwnership!['group'],
            fileSystem: fileSystem);
      } catch (e) {
        logger.severe(
            'Failed to restore original ownership for $destinationPath');
        throw ActionFailedException('Failed to restore ownership', e);
      }
    }

    // Rollback permissions
    if (originalPermissions != null) {
      logger.info('Restoring original permissions for $destinationPath');
      try {
        await FileUtils.chmod(destinationPath, originalPermissions!,
            fileSystem: fileSystem);
      } catch (e) {
        logger.severe(
            'Failed to restore original permissions for $destinationPath');
        throw ActionFailedException('Failed to restore permissions', e);
      }
    }

    for (var module in childModules) {
      await module.rollback();
    }
  }
}
