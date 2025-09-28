import 'package:configr/events/module_events.dart';
import 'package:configr/exceptions.dart'
    show SourceNotFoundException, ActionFailedException;
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/file_utils.dart';
import 'package:configr/utils/logging.dart';
import 'package:configr/utils/event_bus.dart';

class FilePermissionModule extends ResourceModule {
  // State getters
  String? get owner => state['owner'] as String?;
  String? get group => state['group'] as String?;
  String? get mode => state['mode'] as String?;
  Map<String, String>? get originalOwnership =>
      (state['originalOwnership'] as Map<dynamic, dynamic>?)
          ?.cast<String, String>();
  String? get originalPermissions => state['originalPermissions'] as String?;

  FilePermissionModule(super.file, super.action, {super.fileSystem}) {
    final ownerValue = action.properties['owner']?.toString();
    final groupValue = action.properties['group']?.toString();
    final modeValue = action.properties['mode']?.toString();

    if (ownerValue == null && groupValue == null && modeValue == null) {
      throw ArgumentError(
          'At least one of owner, group, or mode must be specified');
    }

    updateState({
      'owner': ownerValue,
      'group': groupValue,
      'mode': modeValue,
      'originalOwnership': null,
      'originalPermissions': null
    });
  }

  @override
  Future<void> execute() async {
    final destinationPath = source;
    emitEvent(StartedEvent(
        moduleId: action.id,
        message: 'Starting permission changes for $source'));

    if (!await FileUtils.fileExists(destinationPath, fileSystem: fileSystem)) {
      logger.severe('Source path $destinationPath does not exist');
      throw SourceNotFoundException(destinationPath);
    }

    executeModules();
    if (isRollingBack) {
      return;
    }

    try {
      final currentOwnership = await FileUtils.getOwnership(destinationPath);
      final currentPermissions =
          await FileUtils.getPermissions(destinationPath);

      emitEvent(StatusUpdateEvent(
          moduleId: action.id,
          level: StatusEvent.info,
          message: 'Current ownership: $currentOwnership'));
      emitEvent(StatusUpdateEvent(
          moduleId: action.id,
          level: StatusEvent.info,
          message: 'Current permissions: $currentPermissions'));

      updateState({
        'originalOwnership': currentOwnership,
        'originalPermissions': currentPermissions
      });

      if (owner != null || group != null) {
        logger.info('Setting file ownership on $destinationPath');
        await FileUtils.chown(destinationPath, owner, group,
            fileSystem: fileSystem, privilegeEscalation: privilegeEscalation);
        emitEvent(StatusUpdateEvent(
            moduleId: action.id,
            level: StatusEvent.info,
            message: 'Changed ownership to $owner:$group'));
      }

      if (mode != null) {
        logger.info('Setting file permissions on $destinationPath to $mode');
        await FileUtils.chmod(destinationPath, mode!,
            fileSystem: fileSystem, privilegeEscalation: privilegeEscalation);
        emitEvent(StatusUpdateEvent(
            moduleId: action.id,
            level: StatusEvent.info,
            message: 'Changed permissions to $mode'));
      }

      // Verify changes
      final verifyOwnership = await FileUtils.getOwnership(destinationPath);
      final verifyPermissions = await FileUtils.getPermissions(destinationPath);

      updateState({
        'currentOwnership': verifyOwnership,
        'currentPermissions': verifyPermissions,
        'changeCompleted': true
      });

      if ((owner != null && verifyOwnership['owner'] != owner) ||
          (group != null && verifyOwnership['group'] != group)) {
        throw ActionFailedException('Failed to set ownership correctly');
      }

      if (mode != null && verifyPermissions != mode) {
        throw ActionFailedException('Failed to set permissions correctly');
      }

      emitEvent(CompletedEvent(
          moduleId: action.id, message: 'Permission changes completed'));
    } catch (e, st) {
      updateState({'error': e.toString(), 'stackTrace': st.toString()});
      rethrow;
    }

    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
    await saveState();
  }

  @override
  Future<void> rollback() async {
    emitEvent(StartedEvent(
        moduleId: action.id, message: 'Rolling back permission changes'));
    try {
      final destinationPath = source;

      if (originalOwnership != null) {
        logger.info('Restoring original ownership for $destinationPath');
        await FileUtils.chown(destinationPath, originalOwnership!['owner'],
            originalOwnership!['group'],
            fileSystem: fileSystem);
      }

      if (originalPermissions != null) {
        logger.info('Restoring original permissions for $destinationPath');
        emitEvent(StatusUpdateEvent(
            moduleId: action.id,
            level: StatusEvent.info,
            message: 'Restoring original permissions'));
        await FileUtils.chmod(destinationPath, originalPermissions!,
            fileSystem: fileSystem);
      }
      updateState({'rollbackCompleted': true});
      emitEvent(
          CompletedEvent(moduleId: action.id, message: 'Rollback completed'));
    } catch (e, st) {
      updateState(
          {'rollbackError': e.toString(), 'rollbackStackTrace': st.toString()});
      rethrow;
    }

    for (var module in childModules) {
      await module.rollback();
    }

    await saveState();
  }
}
