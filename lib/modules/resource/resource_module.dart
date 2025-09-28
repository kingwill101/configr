import 'dart:convert';

import 'package:configr/events/module_events.dart';
import 'package:configr/exceptions.dart';
import 'package:configr/extensions/string.dart';
import 'package:configr/models/action.dart';
import 'package:configr/models/file_model.dart';
import 'package:configr/modules/module.dart';
import 'package:configr/modules/resource/backup.dart';
import 'package:configr/modules/resource/compress.dart';
import 'package:configr/modules/resource/copy.dart';
import 'package:configr/modules/resource/decompress.dart';
import 'package:configr/modules/resource/delete.dart';
import 'package:configr/modules/resource/download.dart';
import 'package:configr/modules/resource/echo.dart';
import 'package:configr/modules/resource/execute.dart';
import 'package:configr/modules/resource/permissions.dart';
import 'package:configr/modules/resource/rename.dart';
import 'package:configr/modules/resource/symlink.dart';
import 'package:configr/modules/resource/touch.dart';
import 'package:configr/modules/resource/validate.dart';
import 'package:configr/utils/event_bus.dart';
import 'package:configr/utils/fs.dart';
import 'package:configr/utils/logging.dart';
import 'package:configr/utils/privellage_escallation.dart';
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
    Map<String, dynamic>? templateVars,
    String? fileTemplate,
  }) {
    loadTemplate();
    loadModules();

    // Restore state from action after subclass initialization (needed for rollback)
    if (action.state.isNotEmpty) {
      updateState(action.state);
    }
  }

  void loadModules() {
    for (final action in action.actions) {
      if (action.type == beforeHookType) {
        _beforeHooks.add(getModuleForAction(file, action, fileSystem));
      } else if (action.type == afterHookType) {
        _afterHooks.add(getModuleForAction(file, action, fileSystem));
      } else if (allowedActions.contains(action.type)) {
        childModules.add(getModuleForAction(file, action, fileSystem));
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

  Future<void> executeModules() async {
    logger.info('Executing modules');
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
    logger.info('Modules executed');
  }
}

/// Factory method to create appropriate module instance
ResourceModule getModuleForAction(
  ResourceModel file,
  Action action, [
  FileSystem? fs,
]) {
  switch (action.type) {
    case 'backup':
      return FileBackupModule(file, action, fileSystem: fs);
    case 'copy':
      return FileCopyModule(file, action, fileSystem: fs);
    case 'symlink':
      return FileSymlinkModule(file, action, fileSystem: fs);
    case 'permissions':
      return FilePermissionModule(file, action, fileSystem: fs);
    case 'compress':
      return FileCompressModule(file, action, fileSystem: fs);
    case 'decompress':
      return FileDecompressModule(file, action, fileSystem: fs);
    case 'delete':
      return FileDeleteModule(file, action, fileSystem: fs);
    case 'download':
      return FileDownloadModule(file, action, fileSystem: fs);
    case 'validate':
      return FileValidateModule(file, action, fileSystem: fs);
    case 'rename':
      return FileRenameModule(file, action, fileSystem: fs);
    case 'execute':
      return FileExecuteModule(file, action, fileSystem: fs);
    case 'touch':
      return FileTouchModule(file, action, fileSystem: fs);
    case 'echo':
      return FileEchoModule(file, action, fileSystem: fs);
    default:
      throw Exception('Unknown action type: ${action.type}');
  }
}
