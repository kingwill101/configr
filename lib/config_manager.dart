import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:configr/exceptions.dart';
import 'package:configr/extensions/string.dart';
import 'package:configr/models/lockfile_data.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/config.dart';
import 'package:configr/utils/logging.dart';
import 'package:configr/utils/privellage_escallation.dart';
import 'package:crypto/crypto.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as path;

import 'models/command.dart';
import 'models/config.dart';
import 'models/file_model.dart';
import 'utils/command_executor.dart';
import 'utils/file_utils.dart';
import 'utils/lockfile_manager.dart';
import 'utils/template_renderer.dart';

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

  ConfigManager(
      {PrivilegeEscalation? privilegeEscalation,
      FileSystem? fileSystem,
      this.repoUrl,
      String? path,
      ConfigOptions? options,
      this.configPath})
      : options = options ?? ConfigOptions(),
        config = Config(options: options),
        fileSystem = fileSystem ?? const LocalFileSystem(),
        localPath = path ?? fileSystem!.currentDirectory.path,
        privilegeEscalation =
            privilegeEscalation ?? InteractiveSudoEscalation() {
    lockfileManager = LockfileManager('$localPath/lockfile.json',
        fileSystem: this.fileSystem);
    templateRenderer = TemplateRenderer();
  }

  Future<void> load() async {
    final configFile = fileSystem.file(
        configPath ?? path.join(fileSystem.currentDirectory.path, 'config'));
    print("Config ${configFile.path}");
    if (!await configFile.exists()) {
      throw Exception('Config file not found');
    }
    resolvedConfigPath = configFile.path;
    final loaded = await loadConfig(resolvedConfigPath, fileSystem: fileSystem);
    format = loaded.$2;

    config = loaded.$1.copyWith(options: options);
  }

  Future<String> computeConfigChecksum() async {
    final configFile = fileSystem.file(resolvedConfigPath);
    final contents = await configFile.readAsString();
    return sha256.convert(utf8.encode(contents)).toString();
  }

  Future<bool> _shouldApplyResource(
      ResourceModel resource, LockfileData? lockfileData) {
    // If no lockfile or force option, always apply
    if (lockfileData == null || options.force) {
      return Future.value(true);
    }

    // Find matching resource in lockfile
    final lockfileResource = lockfileData.resources.firstWhereOrNull(
      (r) =>
          r.source.clean() == resource.source.clean() &&
          r.destination.clean() == resource.destination.clean(),
    );

    // If resource not in lockfile, apply it
    if (lockfileResource == null) {
      return Future.value(true);
    }

    // Check if all actions were completed successfully
    if (lockfileResource.status != 'completed') {
      return Future.value(true);
    }

    // Check if actions or their properties have changed
    if (resource.actions.length != lockfileResource.actions.length) {
      return Future.value(true);
    }

    // Compare actions and their checksums
    for (var i = 0; i < resource.actions.length; i++) {
      final action = resource.actions[i];
      final lockAction = lockfileResource.actions[i];

      if (action.type != lockAction.type ||
          !const MapEquality()
              .equals(action.properties, lockAction.properties) ||
          lockAction.status != 'completed') {
        return Future.value(true);
      }

      // For file operations, verify file hasn't changed
      if (action.type == 'copy' || action.type == 'template') {
        return FileUtils.computeFileHash(resource.destination.clean(),
                fileSystem: fileSystem)
            .then((currentHash) => currentHash != lockAction.sha256);
      }
    }

    logger.info('Skipping already applied resource: ${resource.source}');
    return Future.value(false);
  }

  Future<void> applyConfig() async {
    List<ModuleException> errors = [];
    LockfileData? lockfileData;
    bool madeChanges = false;
    final currentChecksum = await computeConfigChecksum();

    // Load existing lockfile data
    try {
      lockfileData = await lockfileManager.readLockfile();

      // If config file has changed, ignore lockfile
      if (lockfileData.configChecksum != currentChecksum) {
        logger.info('Config file has changed, applying all resources');
        lockfileData = null;
        madeChanges = true;
      }
    } catch (e) {
      logger.info('No valid lockfile found, will apply all resources');
      madeChanges = true;
    }

    await _runScripts(config.preApplyScripts);

    for (var resource in config.resources) {
      try {
        // Check if we should apply this resource
        if (!await _shouldApplyResource(resource, lockfileData)) {
          // If we're not applying the resource, copy its state from lockfile
          if (lockfileData != null) {
            final lockResource = lockfileData.resources.firstWhereOrNull((r) =>
                r.source.clean() == resource.source.clean() &&
                r.destination.clean() == resource.destination.clean());
            if (lockResource != null) {
              resource.status = lockResource.status;
              for (var i = 0; i < resource.actions.length; i++) {
                resource.actions[i].status = lockResource.actions[i].status;
                resource.actions[i].sha256 = lockResource.actions[i].sha256;
                resource.actions[i].timestamp =
                    lockResource.actions[i].timestamp;
              }
            }
          }
          continue;
        }

        madeChanges = true;
        await _processFile(resource);
        resource.status = 'completed';

        // Update checksums for file operations
        for (var action in resource.actions) {
          if (action.type == 'copy' || action.type == 'template') {
            action.sha256 = await FileUtils.computeFileHash(
                resource.destination.clean(),
                fileSystem: fileSystem);
            action.status = 'completed';
            action.timestamp = DateTime.now().toIso8601String();
          }
        }
      } on ModuleException catch (e, stackTrace) {
        logger.severe('Failed to process file ${resource.source}: ${e.message}',
            e.cause, stackTrace);
        resource.status = 'failed';
        errors.add(e);
        if (config.options.failFast) {
          break;
        }
      }
    }

    // Only update lockfile if we made changes
    if (madeChanges) {
      final newLockfileData = LockfileData(
        resources: config.resources,
        commands: config.commands,
        packages: config.packages,
        configChecksum: currentChecksum,
      );
      await lockfileManager.writeLockfile(newLockfileData);
    }

    if (errors.isNotEmpty) {
      throw ConfigurationFailedException(errors);
    }
  }

  Future<void> _processFile(ResourceModel file) async {
    for (var action in file.actions) {
      final mod = await getModuleForAction(file, action, fileSystem);
      try {
        logger.info('Applying action(${file.source}): ${mod.action.type}');
        await mod();
        logger.info('Action completed(${file.source}): ${mod.action.type}');
      } on ModuleException catch (e, stackTrace) {
        logger.severe('Action failed (${mod.action.type}): ${e.message}',
            e.cause, stackTrace);
        await mod.rollback();
        rethrow;
      } catch (e, stackTrace) {
        logger.severe(
            'Unexpected error in action (${mod.action.type})', e, stackTrace);
        await mod.rollback();
        throw ActionFailedException(
            'Unexpected error in ${mod.action.type}', e, stackTrace);
      }
    }
  }

  Future<void> _runScripts(List<String> scripts) async {
    for (var script in scripts) {
      final scriptPath = path.join(localPath!, script);
      if (await fileSystem.file(scriptPath).exists()) {
        await CommandExecutor.execute(
            Command(name: script, command: scriptPath), privilegeEscalation);
      } else {
        print('Warning: Script not found: $scriptPath');
      }
    }
  }

  Future<void> saveConfig() async {
    await updateConfig(resolvedConfigPath, config);
  }
}
