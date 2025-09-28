import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:configr/exceptions.dart';
import 'package:configr/models/lockfile_data.dart';
import 'package:configr/modules/resource/resource_module.dart'
    show getModuleForAction;
import 'package:configr/ui/handlers/base_handler.dart';
import 'package:configr/ui/handlers/cli_handler.dart';
import 'package:configr/utils/config.dart';
import 'package:configr/utils/event_bus.dart';
import 'package:configr/utils/logging.dart';
import 'package:configr/utils/privellage_escallation.dart';
import 'package:configr/utils/template_renderer.dart';
import 'package:crypto/crypto.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as path;

import 'models/command.dart';
import 'models/config.dart';
import 'models/file_model.dart';
import 'utils/command_executor.dart';
import 'utils/lockfile_manager.dart';

class ConfigManager {
  ConfigOptions options;
  String? repoUrl;
  String? localPath;
  Config config;
  String? configPath;
  late ConfigFormat format;
  late LockfileManager lockfileManager;
  final PrivilegeEscalation privilegeEscalation;
  late TemplateRenderer templateRenderer;
  final FileSystem fileSystem;
  late String resolvedConfigPath;
  final UIHandler uiHandler;

  ConfigManager({
    PrivilegeEscalation? privilegeEscalation,
    UIHandler? uiHandler,
    FileSystem? fileSystem,
    this.repoUrl,
    String? path,
    ConfigOptions? options,
    this.configPath,
  }) : options = options ?? ConfigOptions(),
       uiHandler = uiHandler ?? CLIHandler(),
       config = Config(options: options),
       fileSystem = fileSystem ?? const LocalFileSystem(),
       localPath = path ?? fileSystem!.currentDirectory.path,
       privilegeEscalation =
           privilegeEscalation ?? InteractiveSudoEscalation() {
    lockfileManager = LockfileManager(
      '$localPath/lockfile.json',
      fileSystem: this.fileSystem,
    );
    templateRenderer = TemplateRenderer();
    EventBus().stream.listen((event) {
      this.uiHandler.handleEvent(event);
    });
  }

  Future<void> load() async {
    uiHandler.start();
    try {
      final configFile = fileSystem.file(
        configPath ?? path.join(fileSystem.currentDirectory.path, 'config'),
      );
      print("Config ${configFile.path}");
      if (!await configFile.exists()) {
        throw Exception('Config file not found');
      }
      resolvedConfigPath = configFile.path;
      final loaded = await loadConfig(
        resolvedConfigPath,
        fileSystem: fileSystem,
      );
      format = loaded.$2;

      config = loaded.$1.copyWith(options: options);
    } finally {
      uiHandler.stop();
    }
  }

  Future<String> computeConfigChecksum() async {
    final configFile = fileSystem.file(resolvedConfigPath);
    final contents = await configFile.readAsString();
    return sha256.convert(utf8.encode(contents)).toString();
  }

  Future<bool> _shouldApplyResource(
    ResourceModel resource,
    LockfileData? lockfileData,
  ) async {
    // If no lockfile or force option, always apply
    if (lockfileData == null || options.force) {
      if (options.force) {
        logger.info('Force option set, will apply resource ${resource.id}');
      }
      return true;
    }

    // Find matching resource in lockfile
    final lockfileResource = lockfileData.resources.firstWhereOrNull(
      (r) => r.id == resource.id,
    );

    // If resource not in lockfile or status not completed, apply it
    if (lockfileResource == null || lockfileResource.status != 'completed') {
      return true;
    }

    try {
      // Compare the resource's stored hash with lockfile
      if (resource.sha256 != lockfileResource.sha256) {
        logger.info('Resource ${resource.id} state changed, will apply');
        return true;
      }

      // Check each action's stored hash
      for (final action in resource.actions) {
        final lockAction = lockfileResource.actions.firstWhereOrNull(
          (a) => a.id == action.id,
        );
        try {
          if (lockAction == null || lockAction.status != 'completed') {
            logger.info('Action ${action.id} changed or incomplete');
            return true;
          }
        } catch (e, st) {
          // If we can't compute checksums, err on the side of caution and apply
          logger.warning('Error checking resource state, will apply', e, st);
          return true;
        }
      }

      logger.info('Resource ${resource.id} unchanged, skipping');
      return false;
    } catch (e, st) {
      // If we can't compute checksums, err on the side of caution and apply
      logger.warning('Error checking resource state, will apply', e, st);
      return true;
    }
  }

  Future<void> applyConfig() async {
    uiHandler.start();
    try {
      List<ModuleException> errors = [];
      LockfileData? lockfileData;
      bool madeChanges = false;
      final currentChecksum = await computeConfigChecksum();

      try {
        lockfileData = await lockfileManager.readLockfile();
        if (lockfileData.configChecksum != currentChecksum) {
          logger.info('Config file has changed, applying all resources');
          lockfileData = null;
          madeChanges = true;
        }
      } catch (e) {
        logger.info('No valid lockfile found, will apply all resources');
        madeChanges = true;
      }

      for (var script in config.preApplyScripts) {
        final scriptPath = path.join(localPath!, script);
        if (await fileSystem.file(scriptPath).exists()) {
          await CommandExecutor.execute(
            Command(name: script, command: scriptPath),
            privilegeEscalation,
          );
        } else {
          print('Warning: Script not found: $scriptPath');
        }
      }

      try {
        for (var resource in config.resources) {
          try {
            if (!(await _shouldApplyResource(resource, lockfileData))) {
              if (lockfileData != null) {
                final lockResource = lockfileData.resources.firstWhereOrNull(
                  (r) => r.id == resource.id,
                );
                if (lockResource != null) {
                  resource.status = lockResource.status;
                  for (var action in resource.actions) {
                    final lockAction = lockResource.actions.firstWhereOrNull(
                      (a) => a.id == action.id,
                    );
                    if (lockAction != null) {
                      action.status = lockAction.status;
                      action.sha256 = lockAction.sha256;
                      action.timestamp = lockAction.timestamp;
                    }
                  }
                }
              }
              continue;
            }

            madeChanges = true;
            for (var action in resource.actions) {
              final mod = getModuleForAction(resource, action, fileSystem);
              try {
                logger.info(
                  'StartResource(${resource.source}): ${mod.action.type}',
                );
                await mod();
                action.sha256 = await mod.computeInitialStateHash();
                action.status = 'completed';
                action.timestamp = DateTime.now().toIso8601String();
                logger.info(
                  'EndResource(${resource.source}): ${mod.action.type}',
                );
                await mod.saveState();
              } on ModuleException catch (e, st) {
                logger.severe(
                  'Resource failed (${mod.action.type}): ${e.message}',
                  e.cause,
                  st,
                );
                await mod.rollback();
                rethrow;
              }
            }
            resource.status = 'completed';
          } on ModuleException catch (e) {
            resource.status = 'failed';
            errors.add(e);
            if (config.options.failFast) break;
          }
        }
      } finally {
        if (madeChanges) {
          await lockfileManager.writeLockfile(
            LockfileData(
              resources: config.resources,
              commands: config.commands,
              packages: config.packages,
              configChecksum: currentChecksum,
            ),
          );
        }
      }

      if (errors.isNotEmpty) {
        throw ConfigurationFailedException(errors);
      }
    } finally {
      uiHandler.stop();
    }
  }

  Future<void> rollbackConfig({int? count}) async {
    uiHandler.start();
    try {
      List<ModuleException> errors = [];
      final lockfileData = await lockfileManager.readLockfile();

      // Get completed resources from lockfile in reverse order
      final completedResources = lockfileData.resources
          .where((r) => r.status == 'completed')
          .toList()
          .reversed
          .toList();

      // Limit resources to rollback if count specified
      final resourcesToRollback = count != null
          ? completedResources.take(count).toList()
          : completedResources;

      for (var lockfileResource in resourcesToRollback) {
        try {
          // Find corresponding config resource for module creation
          final configResource = config.resources.firstWhereOrNull(
            (r) => r.id == lockfileResource.id,
          );

          if (configResource == null) {
            logger.warning(
              'Config resource not found for ${lockfileResource.id}',
            );
            continue;
          }

          for (var lockfileAction in lockfileResource.actions.reversed) {
            final mod = getModuleForAction(
              configResource,
              lockfileAction,
              fileSystem,
            );
            try {
              logger.info(
                'Rolling back resource ${lockfileResource.source}: ${lockfileAction.type}',
              );
              await mod.rollback();
              lockfileAction.status = 'rolledback';
              lockfileAction.timestamp = DateTime.now().toIso8601String();
            } on ModuleException catch (e, st) {
              logger.severe(
                'Rollback failed for ${lockfileAction.type}: ${e.message}',
                e.cause,
                st,
              );
              errors.add(e);
              if (config.options.failFast) break;
            }
          }
          lockfileResource.status = 'rolledback';
        } on ModuleException catch (e) {
          errors.add(e);
          if (config.options.failFast) break;
        }
      }

      await lockfileManager.writeLockfile(lockfileData);

      if (errors.isNotEmpty) {
        throw ConfigurationFailedException(errors);
      }
    } finally {
      uiHandler.stop();
    }
  }

  Future<void> saveConfig() async {
    uiHandler.start();
    try {
      await updateConfig(resolvedConfigPath, config);
    } finally {
      uiHandler.stop();
    }
  }
}
