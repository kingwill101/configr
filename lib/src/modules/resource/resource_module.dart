import 'dart:convert';

import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/extensions/string.dart';
import 'package:configr/src/models/action.dart';
import 'package:configr/src/models/file_model.dart';
import 'package:configr/src/modules/module.dart';
import 'package:configr/src/modules/resource/backup.dart';
import 'package:configr/src/modules/resource/compress.dart';
import 'package:configr/src/modules/resource/copy.dart';
import 'package:configr/src/modules/resource/decompress.dart';
import 'package:configr/src/modules/resource/delete.dart';
import 'package:configr/src/modules/resource/download.dart';
import 'package:configr/src/modules/resource/echo.dart';
import 'package:configr/src/modules/resource/execute.dart';
import 'package:configr/src/modules/resource/permissions.dart';
import 'package:configr/src/modules/resource/rename.dart';
import 'package:configr/src/modules/resource/symlink.dart';
import 'package:configr/src/modules/resource/touch.dart';
import 'package:configr/src/modules/resource/validate.dart';
import 'package:configr/src/modules/resource/template.dart';
import 'package:configr/src/modules/resource/sync.dart';
import 'package:configr/src/modules/resource/package.dart';
import 'package:configr/src/modules/resource/systemd.dart';
import 'package:configr/src/modules/resource/file.dart';
import 'package:configr/src/modules/resource/git.dart';
import 'package:configr/src/modules/resource/network.dart';
import 'package:configr/src/utils/fs.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:configr/src/utils/privilege_escalation.dart';
import 'package:crypto/crypto.dart';
import 'package:file/file.dart';
import 'package:liquify/liquify.dart' as liquify;
import 'package:path/path.dart';

abstract class ResourceModule extends Module {
  static const beforeHookType = 'before';
  static const afterHookType = 'after';

  final Map<String, dynamic> _moduleState = {};
  final List<ResourceModule> _beforeHooks = [];
  final List<ResourceModule> _afterHooks = [];

  Map<String, dynamic> get state => _moduleState;

  void updateState(Map<String, dynamic> newState) {
    _moduleState.addAll(newState);
  }

  final ResourceModel file;
  final Action action;
  final FileSystem? fileSystem;
  final List<String> allowedActions;
  final PrivilegeEscalation? privilegeEscalation;
  final EventBus? eventBus;
  Map<String, dynamic> vars = {};
  List<ResourceModule> childModules = [];
  bool isRollingBack = false;
  File? templateFile;

  ResourceModule(
    this.file,
    this.action, {
    this.allowedActions = const [],
    this.fileSystem,
    this.privilegeEscalation,
    this.eventBus,
    Map<String, dynamic>? templateVars,
    String? fileTemplate,
  }) {
    loadTemplate();
    loadModules();

    if (action.state.isNotEmpty) {
      updateState(action.state);
    }
  }

  void emitEvent(ModuleEvent event) {
    if (eventBus != null) {
      eventBus!.emit(event);
    }
  }

  void loadModules() {
    for (final action in action.actions) {
      if (action.type == beforeHookType) {
        // For before hooks, create a module that executes the nested actions
        _beforeHooks.add(createHookModule(file, action, fileSystem, eventBus));
      } else if (action.type == afterHookType) {
        // For after hooks, create a module that executes the nested actions
        _afterHooks.add(createHookModule(file, action, fileSystem, eventBus));
      } else if (allowedActions.contains(action.type)) {
        childModules.add(getModuleForAction(file, action, fileSystem, eventBus));
      }
    }
  }

  Future<void> rollbackChildren() async {
    for (final module in childModules.reversed) {
      await module.rollback();
    }
  }

  String get source {
    final path = (action.properties["source"] as String? ?? file.source)
        .normalizePath();
    if (path.startsWith("http")) {
      return file.source;
    }
    return templateFile != null
        ? resolvePath(templateFile!.path)
        : resolvePath(path);
  }

  String resolvePath(String path) {
    if (isRelative(path)) {
      return join((fileSystem ?? fs).currentDirectory.path, path);
    }
    return path;
  }

  String get destination => resolvePath(
    action.properties['destination'] as String? ?? file.destination,
  ).normalizePath();

  void loadTemplate() {
    if (file.template != null && file.template!.template != null) {
      final templateContent = (fileSystem ?? fs).file(file.template!.template!);

      if (!templateContent.existsSync()) {
        throw ActionFailedException(
          'Template file ${templateContent.path} does not exist',
        );
      }

      final tContent = liquify.Template.parse(
        templateContent.readAsStringSync(),
        data: file.template!.vars ?? {},
      ).render();
      var cacheDir = (fileSystem ?? fs).directory(appDirs.cache);

      if (!cacheDir.existsSync()) {
        try {
          cacheDir.createSync();
        } catch (e) {
          cacheDir = (fileSystem ?? fs).systemTempDirectory.createTempSync();
        }
      }

      String templateFilePath = join(cacheDir.path, file.template!.template!);
      templateFile = (fileSystem ?? fs).file(templateFilePath);
      templateFile?.createSync(recursive: true);
      templateFile?.writeAsStringSync(tContent);
    }
  }

  Future<String?> computeInitialStateHash() async {
    try {
      final baseState = await _getBaseState();

      if (baseState == null && _moduleState.isEmpty) {
        return null;
      }

      final state = {...?baseState, 'moduleState': _moduleState};

      return sha256.convert(utf8.encode(json.encode(state))).toString();
    } catch (e, st) {
      logger.warning(
        'Failed to compute initial state hash for ${action.type}',
        e,
        st,
      );
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getBaseState() async {
    return {
      'id': file.id,
      'source': source,
      'destination': destination,
      'type': file.type,
      'action': {
        'id': action.id,
        'type': action.type,
        'properties': action.properties,
      },
      'moduleState': state,
    };
  }

  Future<Map<String, dynamic>?> getAdditionalState() async => null;

  Future<void> call() async {
    emitEvent(
      StartedEvent(moduleId: action.id, message: 'Starting ${action.type}'),
    );

    try {
      await execute();
      emitEvent(
        CompletedEvent(
          moduleId: action.id,
          message: 'Completed ${action.type}',
        ),
      );
    } catch (e) {
      emitEvent(
        FailedEvent(
          moduleId: action.id,
          message: 'Failed ${action.type}: ${e.toString()}',
        ),
      );
      rethrow;
    }
  }

  // Abstract method for module-specific logic
  Future<void> execute();

  Future<void> rollback() async {
    // Rollback in reverse order
    for (final hook in _afterHooks.reversed) {
      await hook.rollback();
    }

    await rollbackChildren();

    for (final hook in _beforeHooks.reversed) {
      await hook.rollback();
    }
  }

  Future<void> saveState() async {
    action.state = state;
  }

  /// Determine if this module should use privilege escalation
  bool shouldUsePrivilegeEscalation() {
    // Check if action has explicit require_root override
    final actionRequireRoot = action.properties['require_root'] as bool?;
    if (actionRequireRoot != null) {
      return actionRequireRoot;
    }
    
    // Fall back to resource-level require_root setting from parent properties
    return action.parent?['require_root'] as bool? ?? false;
  }

  Future<void> executeModules() async {
    logger.info('Executing modules');
    
    // Execute before hooks first
    for (final hook in _beforeHooks) {
      if (!isRollingBack) {
        try {
          logger.info('Applying before hook: ${hook.action.type}');
          await hook();
          logger.info('Before hook completed: ${hook.action.type}');
        } catch (e) {
          logger.severe('Error executing before hook ${hook.runtimeType}: $e');
          isRollingBack = true;
          await hook.rollback();
        }
      } else {
        await hook.rollback();
      }
    }
    
    // Execute main child modules
    for (final module in childModules) {
      if (!isRollingBack) {
        try {
          logger.info('Applying action: ${module.action.type}');
          await module();
          logger.info('Action completed: ${module.action.type}');
        } catch (e) {
          logger.severe('Error executing module ${module.runtimeType}: $e');
          isRollingBack = true;
          await module.rollback();
        }
      } else {
        await module.rollback();
      }
    }
    
    // Execute after hooks last
    for (final hook in _afterHooks) {
      if (!isRollingBack) {
        try {
          logger.info('Applying after hook: ${hook.action.type}');
          await hook();
          logger.info('After hook completed: ${hook.action.type}');
        } catch (e) {
          logger.severe('Error executing after hook ${hook.runtimeType}: $e');
          isRollingBack = true;
          await hook.rollback();
        }
      } else {
        await hook.rollback();
      }
    }
    
    logger.info('Modules executed');
  }
}

/// Create a module for executing hook actions
ResourceModule createHookModule(
  ResourceModel file,
  Action hookAction, [
  FileSystem? fs,
  EventBus? eventBus,
]) {
  return HookExecutionModule(file, hookAction, fileSystem: fs, eventBus: eventBus);
}

/// Module for executing hook actions
class HookExecutionModule extends ResourceModule {
  HookExecutionModule(
    ResourceModel file,
    Action hookAction, {
    FileSystem? fileSystem,
    EventBus? eventBus,
  }) : super(
          file,
          Action(
            id: '${hookAction.type}_${file.id}',
            type: hookAction.type,
            actions: hookAction.actions,
            properties: hookAction.properties,
          ),
          allowedActions: const [],
          fileSystem: fileSystem,
          eventBus: eventBus,
        );

  @override
  Future<void> execute() async {
    for (final nestedAction in action.actions) {
      final module = getModuleForAction(
        file, nestedAction, fileSystem, eventBus,
      );
      await module();
    }
  }
}

/// Create a resource module for handling multiple actions
ResourceModule createResourceModule(
  ResourceModel resource, [
  FileSystem? fs,
  EventBus? eventBus,
]) {
  return GenericResourceModule(resource, fileSystem: fs, eventBus: eventBus);
}

/// Generic resource module that handles multiple actions for a resource
class GenericResourceModule extends ResourceModule {
  GenericResourceModule(
    ResourceModel file, {
    FileSystem? fileSystem,
    EventBus? eventBus,
  }) : super(
          file,
          Action(type: 'resource', actions: file.actions),
          allowedActions: const [
            'backup', 'copy', 'symlink', 'permissions', 'compress', 'decompress',
            'delete', 'download', 'validate', 'rename', 'execute', 'touch',
            'echo', 'template', 'sync', 'package', 'systemd', 'file', 'git', 'network'
          ],
          fileSystem: fileSystem,
          eventBus: eventBus,
        );

  @override
  Future<void> execute() async {
    await executeModules();
  }
}

/// Factory method to create appropriate module instance
ResourceModule getModuleForAction(
  ResourceModel file,
  Action action, [
  FileSystem? fs,
  EventBus? eventBus,
]) {
  switch (action.type) {
    case 'backup':
      return FileBackupModule(file, action, fileSystem: fs, eventBus: eventBus);
    case 'copy':
      return FileCopyModule(file, action, fileSystem: fs, eventBus: eventBus);
    case 'symlink':
      return FileSymlinkModule(file, action, fileSystem: fs, eventBus: eventBus);
    case 'permissions':
      return FilePermissionModule(file, action, fileSystem: fs, eventBus: eventBus);
    case 'compress':
      return FileCompressModule(file, action, fileSystem: fs, eventBus: eventBus);
    case 'decompress':
      return FileDecompressModule(file, action, fileSystem: fs, eventBus: eventBus);
    case 'delete':
      return FileDeleteModule(file, action, fileSystem: fs, eventBus: eventBus);
    case 'download':
      return FileDownloadModule(file, action, fileSystem: fs, eventBus: eventBus);
    case 'validate':
      return FileValidateModule(file, action, fileSystem: fs, eventBus: eventBus);
    case 'rename':
      return FileRenameModule(file, action, fileSystem: fs, eventBus: eventBus);
    case 'execute':
      return FileExecuteModule(file, action, fileSystem: fs, eventBus: eventBus);
    case 'touch':
      return FileTouchModule(file, action, fileSystem: fs, eventBus: eventBus);
    case 'echo':
      return FileEchoModule(file, action, fileSystem: fs, eventBus: eventBus);
    case 'template':
      return FileTemplateModule(file, action, fileSystem: fs, eventBus: eventBus);
    case 'sync':
      return FileSyncModule(file, action, fileSystem: fs, eventBus: eventBus);
    case 'package':
      return FilePackageModule(file, action, fileSystem: fs, eventBus: eventBus);
    case 'systemd':
      return FileSystemdModule(file, action, fileSystem: fs, eventBus: eventBus);
    case 'file':
      return FileFileModule(file, action, fileSystem: fs, eventBus: eventBus);
    case 'git':
      return FileGitModule(file, action, fileSystem: fs, eventBus: eventBus);
    case 'network':
      return FileNetworkModule(file, action, fileSystem: fs, eventBus: eventBus);
    default:
      throw Exception('Unknown action type: ${action.type}');
  }
}
