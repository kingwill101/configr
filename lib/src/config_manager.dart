import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:configr/src/configr_config.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/models/lockfile_data.dart';
import 'package:configr/src/modules/resource/resource_module.dart'
    show createResourceModule;
import 'package:configr/src/cli/ui/handlers/base_handler.dart';
import 'package:configr/src/cli/ui/handlers/cli_handler.dart';
import 'package:configr/src/cli/ui/handlers/interactive_handler.dart';
import 'package:configr/src/utils/config.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:configr/src/utils/privilege_escalation.dart';
import 'package:configr/src/utils/template_renderer.dart';
import 'package:crypto/crypto.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as path;

import 'models/command.dart';
import 'models/config.dart';
import 'models/file_model.dart';
import 'utils/command_executor.dart';
import 'utils/lockfile_manager.dart';

class ConfigManager {
  final ConfigrConfig configrConfig;
  ConfigOptions options;
  String? repoUrl;
  String? localPath;
  Config config;
  String? configPath;
  late ConfigFormat format;
  late LockfileManager lockfileManager;
  final PrivilegeEscalation privilegeEscalation;
  final bool keepPrivilegeLock;
  late TemplateRenderer templateRenderer;
  final FileSystem fileSystem;
  late String resolvedConfigPath;
  final UIHandler uiHandler;
  final bool interactiveMode;
  final bool verboseMode;
  final bool debugMode;
  final bool dryRunMode;
  final EventBus _eventBus;

  ConfigManager({
    required this.configrConfig,
    this.repoUrl,
    String? path,
    this.configPath,
    this.interactiveMode = false,
    this.verboseMode = false,
    this.debugMode = false,
    this.dryRunMode = false,
    this.keepPrivilegeLock = false,
  }) : _eventBus = configrConfig.eventBus,
       options = configrConfig.options,
       config = Config(options: configrConfig.options),
       fileSystem = configrConfig.fileSystem,
       localPath =
           path ??
           configrConfig.localPath ??
           configrConfig.fileSystem.currentDirectory.path,
       uiHandler = _resolveUIHandler(
         configrConfig.uiHandler,
         interactiveMode,
         verboseMode,
         debugMode,
       ),
       privilegeEscalation = _resolvePrivilegeEscalation(
         configrConfig.privilegeEscalation,
         configrConfig.uiHandler,
         interactiveMode,
         verboseMode,
         debugMode,
         usePrivilegeLock: keepPrivilegeLock,
         privilegeLock: configrConfig.privilegeLock,
       ) {
    lockfileManager = LockfileManager(
      '$localPath/lockfile.json',
      fileSystem: fileSystem,
    );
    templateRenderer = TemplateRenderer();

    if (uiHandler is InteractiveHandler) {
      (uiHandler as InteractiveHandler).setEventBus(_eventBus);
    }

    _eventBus.stream.listen((event) {
      uiHandler.handleEvent(event);
    });
  }

  bool get isDryRun => dryRunMode;

  void logDryRun(String message) {
    if (dryRunMode) {
      print('🔍 [DRY-RUN] $message');
    }
  }

  void emitEvent(ModuleEvent event) {
    _eventBus.emit(event);
  }

  static UIHandler _resolveUIHandler(
    UIHandler? uiHandler,
    bool interactiveMode,
    bool verboseMode,
    bool debugMode,
  ) {
    if (uiHandler != null) {
      if (interactiveMode) {
        uiHandler.enableInteractiveMode();
      }
      if (verboseMode && uiHandler is CLIHandler) {
        uiHandler.enableVerboseMode();
      }
      if (debugMode && uiHandler is CLIHandler) {
        uiHandler.enableDebugMode();
      }
      return uiHandler;
    }

    if (interactiveMode) {
      return InteractiveHandler(
        eventBus: EventBus(),
        verboseMode: verboseMode,
        debugMode: debugMode,
        interactiveMode: interactiveMode,
      );
    }

    return CLIHandler();
  }

  static PrivilegeEscalation _resolvePrivilegeEscalation(
    PrivilegeEscalation? privilegeEscalation,
    UIHandler? uiHandler,
    bool interactiveMode,
    bool verboseMode,
    bool debugMode, {
    bool usePrivilegeLock = false,
    PrivilegeLock? privilegeLock,
  }) {
    if (privilegeEscalation != null) {
      return privilegeEscalation;
    }

    final handler = _resolveUIHandler(
      uiHandler,
      interactiveMode,
      verboseMode,
      debugMode,
    );
    return InteractiveSudoEscalation(
      uiHandler: handler,
      keepPrivilegeLock: usePrivilegeLock,
      privilegeLock: privilegeLock,
    );
  }

  Future<void> load() async {
    uiHandler.start();
    try {
      final configFile = fileSystem.file(
        configPath ?? path.join(fileSystem.currentDirectory.path, 'config'),
      );
      print("Config ${configFile.path}");
      if (!await configFile.exists()) {
        throw ConfigFileNotFoundException(
          'Configuration file not found: ${configFile.path}\n\nPlease run this command from a directory containing a config file, or specify a config file path.',
        );
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
    if (lockfileData == null || options.force) {
      if (options.force) {
        logger.info('Force option set, will apply resource ${resource.id}');
      }
      return true;
    }

    final lockfileResource = lockfileData.resources.firstWhereOrNull(
      (r) => r.id == resource.id,
    );

    if (lockfileResource == null || lockfileResource.status != 'completed') {
      return true;
    }

    try {
      if (resource.sha256 != lockfileResource.sha256) {
        logger.info('Resource ${resource.id} state changed, will apply');
        return true;
      }

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
          logger.warning('Error checking resource state, will apply', e, st);
          return true;
        }
      }

      logger.info('Resource ${resource.id} unchanged, skipping');
      return false;
    } catch (e, st) {
      logger.warning('Error checking resource state, will apply', e, st);
      return true;
    }
  }

  Future<void> applyConfig() async {
    uiHandler.start();
    try {
      if (dryRunMode) {
        logDryRun('Starting configuration application (dry-run mode)');
      }

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
          if (dryRunMode) {
            logDryRun('Would execute pre-apply script: $scriptPath');
          } else {
            await CommandExecutor.execute(
              Command(name: script, command: scriptPath),
              privilegeEscalation,
            );
          }
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
            emitEvent(
              ResourceStartedEvent(
                moduleId: 'config-manager',
                resourceId: resource.id,
                resourceType: resource.type ?? 'unknown',
                source: resource.source,
                destination: resource.destination,
                actionCount: resource.actions.length,
              ),
            );

            final startTime = DateTime.now();
            int completedActions = 0;

            final mod = createResourceModule(resource, fileSystem);
            try {
              if (dryRunMode) {
                logDryRun(
                  'Would apply resource: ${resource.id} (${resource.type})',
                );
                logDryRun('  Source: ${resource.source}');
                logDryRun('  Destination: ${resource.destination}');
                logDryRun('  Actions: ${resource.actions.length}');
                for (var action in resource.actions) {
                  final source = action.properties['source'] ?? 'unknown';
                  final destination =
                      action.properties['destination'] ?? 'unknown';
                  logDryRun('    - ${action.type}: $source -> $destination');
                }
                for (var action in resource.actions) {
                  action.status = 'completed';
                  action.timestamp = DateTime.now().toIso8601String();
                  completedActions++;
                }
              } else {
                await mod();
                for (var action in resource.actions) {
                  action.status = 'completed';
                  action.timestamp = DateTime.now().toIso8601String();
                  completedActions++;
                }
                await mod.saveState();
              }
            } on ModuleException catch (e, st) {
              logger.severe('Resource failed: ${e.message}', e.cause, st);
              if (!dryRunMode) {
                await mod.rollback();
              }
              rethrow;
            }

            final duration = DateTime.now().difference(startTime);
            emitEvent(
              ResourceCompletedEvent(
                moduleId: 'config-manager',
                resourceId: resource.id,
                resourceType: resource.type ?? 'unknown',
                source: resource.source,
                destination: resource.destination,
                completedActions: completedActions,
                totalActions: resource.actions.length,
                duration: duration,
              ),
            );
            resource.status = 'completed';
          } on ModuleException catch (e) {
            resource.status = 'failed';
            errors.add(e);
            if (config.options.failFast) break;
          }
        }
      } finally {
        if (madeChanges) {
          if (dryRunMode) {
            logDryRun('Would update lockfile with new state');
          } else {
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

      final completedResources = lockfileData.resources
          .where((r) => r.status == 'completed')
          .toList()
          .reversed
          .toList();

      final resourcesToRollback = count != null
          ? completedResources.take(count).toList()
          : completedResources;

      if (resourcesToRollback.isEmpty) {
        emitEvent(
          StatusUpdateEvent(
            moduleId: 'config-manager',
            level: StatusEvent.info,
            message: 'No completed resources found to rollback',
          ),
        );
        await Future.delayed(Duration(milliseconds: 10));
        return;
      }

      emitEvent(
        StatusUpdateEvent(
          moduleId: 'config-manager',
          level: StatusEvent.info,
          message:
              'Found ${resourcesToRollback.length} resource(s) to rollback',
        ),
      );

      for (var lockfileResource in resourcesToRollback) {
        try {
          final configResource = config.resources.firstWhereOrNull(
            (r) => r.id == lockfileResource.id,
          );

          if (configResource == null) {
            logger.warning(
              'Config resource not found for ${lockfileResource.id}',
            );
            continue;
          }

          emitEvent(
            ResourceRollbackStartedEvent(
              moduleId: 'config-manager',
              resourceId: lockfileResource.id,
              resourceType: lockfileResource.type ?? 'unknown',
              source: lockfileResource.source,
              destination: lockfileResource.destination,
              actionCount: lockfileResource.actions.length,
            ),
          );

          final startTime = DateTime.now();
          int rolledbackActions = 0;

          for (var lockfileAction in lockfileResource.actions) {
            final configAction = configResource.actions.firstWhereOrNull(
              (a) => a.id == lockfileAction.id,
            );
            if (configAction != null) {
              configAction.state = lockfileAction.state;
            }
          }

          final mod = createResourceModule(configResource, fileSystem);
          try {
            await mod.rollback();
            for (var lockfileAction in lockfileResource.actions) {
              lockfileAction.status = 'rolledback';
              lockfileAction.timestamp = DateTime.now().toIso8601String();
              rolledbackActions++;
            }
          } on ModuleException catch (e, st) {
            logger.severe('Rollback failed: ${e.message}', e.cause, st);
            errors.add(e);
            if (config.options.failFast) break;
          }

          final duration = DateTime.now().difference(startTime);
          emitEvent(
            ResourceRollbackCompletedEvent(
              moduleId: 'config-manager',
              resourceId: lockfileResource.id,
              resourceType: lockfileResource.type ?? 'unknown',
              source: lockfileResource.source,
              destination: lockfileResource.destination,
              rolledbackActions: rolledbackActions,
              totalActions: lockfileResource.actions.length,
              duration: duration,
            ),
          );

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

      emitEvent(
        StatusUpdateEvent(
          moduleId: 'config-manager',
          level: StatusEvent.info,
          message: 'Rollback completed successfully',
        ),
      );
    } on LockfileNotFoundException catch (e) {
      emitEvent(
        StatusUpdateEvent(
          moduleId: 'config-manager',
          level: StatusEvent.info,
          message: e.message,
        ),
      );
      await Future.delayed(Duration(milliseconds: 10));
    } catch (e, st) {
      logger.severe('Unexpected error during rollback', e, st);
      rethrow;
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
