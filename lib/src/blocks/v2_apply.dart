import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:path/path.dart' as p;
import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/blocks/backup_block.dart';
import 'package:configr/src/cli/ui/handlers/base_handler.dart';
import 'package:configr/src/blocks/compress_block.dart';
import 'package:configr/src/blocks/copy_block.dart';
import 'package:configr/src/blocks/decompress_block.dart';
import 'package:configr/src/blocks/delete_block.dart';
import 'package:configr/src/blocks/download_block.dart';
import 'package:configr/src/blocks/echo_block.dart';
import 'package:configr/src/blocks/execute_block.dart';
import 'package:configr/src/blocks/file_block.dart';
import 'package:configr/src/blocks/git_block.dart';
import 'package:configr/src/blocks/move_block.dart';
import 'package:configr/src/blocks/network_block.dart';
import 'package:configr/src/blocks/package_block.dart';
import 'package:configr/src/blocks/permissions_block.dart';
import 'package:configr/src/blocks/rename_block.dart';
import 'package:configr/src/blocks/symlink_block.dart';
import 'package:configr/src/blocks/sync_block.dart';
import 'package:configr/src/blocks/systemd_block.dart';
import 'package:configr/src/blocks/template_block.dart';
import 'package:configr/src/blocks/touch_block.dart';
import 'package:configr/src/blocks/validate_block.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/models/v2_lockfile_data.dart';
import 'package:configr/src/configr_directories.dart';
import 'package:configr/src/plugins/configr_plugin.dart';
import 'package:configr/src/plugins/lua_plugin.dart';
import 'package:configr/src/reader/handlers/configr_handlers.dart';
import 'package:configr/src/reader/handlers/plugin_block_handler.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:configr/src/utils/privilege_escalation.dart'
    show PrivilegeEscalation;
import 'package:configr/src/utils/v2_lockfile_manager.dart';

import 'package:file/local.dart';
import 'package:i3config/i3config_v2.dart' as i3;

/// Applies a config file using the v2 ActionBlock pipeline.
///
/// Bypasses the old [ConfigManager]/[ResourceModule] path entirely.
/// Instead:
/// 1. Reads and parses the config file via `i3.Config.parse()`
/// 2. If lockfile exists and checksums match, skips unchanged blocks
/// 3. Executes pre-apply scripts (if any)
/// 4. Creates a [i3.ConfigProcessor] and registers v2 block handlers
/// 5. Processes the parsed config — each block executes as it is processed
/// 6. Executes post-apply scripts (if any)
/// 7. Writes a lockfile so [rollbackV2] knows what was applied
///
/// If [dryRun] is true, blocks are parsed and properties read, but
/// [ActionBlock.execute] is not called. Useful for preview/simulation.
///
/// If [failFast] is true, the pipeline stops at the first block error
/// instead of continuing with remaining blocks.
Future<void> applyV2(
  String configPath, {
  EventBus? eventBus,
  bool force = false,
  bool dryRun = false,
  bool failFast = false,
  bool interactive = false,
  bool verbose = false,
  bool debug = false,
  UIHandler? uiHandler,
  PrivilegeEscalation? privilegeEscalation,
  ConfigrPluginLoader? pluginLoader,
}) async {
  final fs = const LocalFileSystem();
  final configFile = fs.file(configPath);
  if (!await configFile.exists()) {
    throw ConfigFileNotFoundException(
      'Configuration file not found: ${configFile.path}',
    );
  }

  // If --force, delete existing lockfile so nothing is skipped.
  if (force) {
    final lockPath = V2LockfileManager.lockPathFor(configPath);
    final lockFile = fs.file(lockPath);
    if (await lockFile.exists()) {
      logger.info('--force: deleting existing lockfile.');
      await lockFile.delete();
    }
  }

  final contents = await configFile.readAsString();
  final currentChecksum = _sha256Hex(contents);

  // Check lockfile for checksum comparison — skip if nothing changed.
  final lockMgr = V2LockfileManager(
    V2LockfileManager.lockPathFor(configPath),
    fileSystem: fs,
  );
  try {
    final existingLock = await lockMgr.read();
    if (existingLock.configChecksum == currentChecksum && !force && !dryRun) {
      logger.info(
        'Config unchanged since last apply — skipping. '
        'Use --force to re-apply.',
      );
      return;
    }
  } catch (_) {
    // No valid lockfile — will apply all blocks.
  }

  // Parse via i3config v2
  final config = i3.Config.parse(contents);

  // Interactive mode — prompt user for confirmation before apply
  // (skipped when --no-interaction/-n is passed)
  if (interactive && !dryRun) {
    final confirmed = uiHandler?.confirm(
          'Apply configuration from ${configPath.split('/').last}?',
          defaultValue: true,
        ) ??
        true;
    if (!confirmed) {
      logger.info('Apply cancelled by user.');
      return;
    }
  }

  if (verbose) {
    logger.info(
      'Config parsed: ${config.statements.length} top-level statement(s)',
    );
  }
  if (debug) {
    logger.fine('Config contents:\n$contents');
  }

  // Execute pre-apply scripts before processing action blocks
  if (!dryRun) {
    final preScripts = _collectScriptsFromConfig(config, 'pre_apply_scripts');
    for (final script in preScripts) {
      logger.info('Executing pre-apply script: $script');
      try {
        await Process.run(
          '/bin/sh',
          ['-c', script],
          runInShell: true,
          workingDirectory: fs.currentDirectory.path,
        );
      } catch (e) {
        logger.warning('Pre-apply script failed: $script — $e');
      }
    }
  }

  // Create processor and register block handlers + plugins
  final processor = i3.ConfigProcessor();
  final appliedBlocks = <AppliedBlockRecord>[];
  processor.context.options['_appliedBlocks'] = appliedBlocks;
  if (failFast) {
    processor.context.options['_failFast'] = true;
  }

  final configDir = p.dirname(p.absolute(configPath));

  // Discover .configr/ directory alongside the config file
  final dotConfigrPath = p.join(configDir, '.configr');
  final configrDirs = ConfigrDirectories(projectConfigrPath: dotConfigrPath);

  // Auto-add .configr/plugins/ as a plugin directory if it exists
  if (pluginLoader != null) {
    final projectPlugins = p.join(dotConfigrPath, 'plugins');
    if (await fs.directory(projectPlugins).exists()) {
      if (!pluginLoader.pluginDirectories.contains(projectPlugins)) {
        pluginLoader.pluginDirectories.add(projectPlugins);
      }
    }
  }

  // Store directory info in processor context so blocks/Lua can access
  processor.context.options['_configrDirs'] = configrDirs;
  processor.context.options['_configrCacheDir'] = configrDirs.cacheDir;
  processor.context.options['_configrBackupDir'] = configrDirs.backupDir;

  // Ensure standard directories exist
  await configrDirs.ensureAll();

  await _registerAllBlocks(
    processor,
    eventBus: eventBus,
    dryRun: dryRun,
    privilegeEscalation: privilegeEscalation,
    pluginLoader: pluginLoader,
    configDir: configDir,
  );

  // Invoke plugin onConfigLoad hooks
  if (pluginLoader != null) {
    final plugins = await pluginLoader.discoverPlugins();
    for (final plugin in plugins) {
      await plugin.onConfigLoad(config);
    }
  }

  // Process — each block executes as it is processed
  await processor.process(config);

  // Invoke plugin onConfigApplied hooks
  if (pluginLoader != null) {
    final plugins = await pluginLoader.discoverPlugins();
    for (final plugin in plugins) {
      await plugin.onConfigApplied(config);
    }
  }

  // Execute post-apply scripts after processing
  if (!dryRun) {
    final postScripts = _collectScriptsFromConfig(config, 'post_apply_scripts');
    for (final script in postScripts) {
      logger.info('Executing post-apply script: $script');
      try {
        await Process.run(
          '/bin/sh',
          ['-c', script],
          runInShell: true,
          workingDirectory: fs.currentDirectory.path,
        );
      } catch (e) {
        logger.warning('Post-apply script failed: $script — $e');
      }
    }
  }

  // Check for errors collected during processing.
  final errors =
      (processor.context.options['_errors'] as List<BlockErrorRecord>?) ??
      <BlockErrorRecord>[];

  if (errors.isNotEmpty) {
    logger.severe(
      'Apply failed — ${errors.length} block(s) encountered errors:',
    );
    for (final err in errors) {
      final location = err.source != null ? ' (${err.source})' : '';
      logger.severe('  - ${err.blockType}: ${err.message}$location');
    }
    // Delete any partial lockfile that may exist from a previous run.
    final lockPath = V2LockfileManager.lockPathFor(configPath);
    final lockFile = fs.file(lockPath);
    if (await lockFile.exists()) {
      await lockFile.delete();
    }
    throw ActionFailedException(
      '${errors.length} block(s) failed during apply. Fix errors and re-run.',
    );
  }

  // Write lockfile with records of what was applied
  if (appliedBlocks.isNotEmpty) {
    await lockMgr.write(
      V2LockfileData(
        appliedBlocks: appliedBlocks,
        configChecksum: currentChecksum,
      ),
    );
    logger.info(
      'Lockfile written with ${appliedBlocks.length} applied block(s).',
    );
  }
}

/// Rolls back previously-applied blocks using the lockfile as the source
/// of truth.
///
/// Uses lockfile records directly to configure ActionBlock instances for
/// rollback — does NOT re-parse the config or match by properties.
/// Each record has the blockType, source, destination, id from apply-time
/// which is more reliable than re-parsing (where singleton handler instances
/// lose per-occurrence state).
///
/// 1. Reads the lockfile to get the list of previously-applied blocks.
/// 2. Looks up each ActionBlock by blockType, sets its properties from
///    the lockfile record, and calls rollback() in reverse order.
/// 3. Removes the rolled-back records from the lockfile.
///
/// The [count] parameter limits rollback to the most recent N blocks.
/// If [dryRun] is true, rollback is simulated (logged but not executed).
Future<void> rollbackV2(
  String configPath, {
  EventBus? eventBus,
  int? count,
  bool dryRun = false,
  ConfigrPluginLoader? pluginLoader,
}) async {
  final fs = const LocalFileSystem();

  // 1. Read the lockfile
  final lockMgr = V2LockfileManager(
    V2LockfileManager.lockPathFor(configPath),
    fileSystem: fs,
  );
  final lockData = await lockMgr.read();

  // --- Verify config checksum before rollback ---
  // If the config file has changed since the lockfile was written, warn the
  // user. Rolling back a changed config could leave the system in an
  // inconsistent state.
  final configFile = fs.file(configPath);
  final currentContents = await configFile.readAsString();
  final currentChecksum = _sha256Hex(currentContents);
  if (lockData.configChecksum != currentChecksum) {
    logger.warning(
      'Config file has changed since apply. '
      'Rollback may produce unexpected results.',
    );
  }

  final allRecords = lockData.appliedBlocks;
  if (allRecords.isEmpty) {
    logger.info('Nothing to rollback — lockfile is empty.');
    return;
  }

  final targetRecords = count != null && count < allRecords.length
      ? allRecords.reversed.take(count).toList()
      : allRecords.reversed.toList();

  if (dryRun) {
    logger.info(
      '[DRY-RUN] Would rollback ${targetRecords.length} block(s) '
      '(${allRecords.length} total recorded).',
    );
    return;
  }

  logger.info(
    'Rolling back ${targetRecords.length} block(s) from lockfile '
    '(${allRecords.length} total recorded).',
  );

  // 2. Build the same ActionBlock map used during apply so we can look up
  //    block instances by type.
  final actionBlockMap = <String, ActionBlock>{};
  ActionBlock make<T extends ActionBlock>(T block) {
    block.fileSystem ??= fs;
    actionBlockMap[block.blockType] = block;
    return block;
  }

  make(BackupBlock(eventBus: eventBus));
  make(CompressBlock(eventBus: eventBus));
  make(CopyBlock(eventBus: eventBus));
  make(DecompressBlock(eventBus: eventBus));
  make(DeleteBlock(eventBus: eventBus));
  make(DownloadBlock(eventBus: eventBus));
  make(EchoBlock(eventBus: eventBus));
  make(ExecuteBlock(eventBus: eventBus));
  make(FileBlock(eventBus: eventBus));
  make(GitBlock(eventBus: eventBus));
  make(MoveBlock(eventBus: eventBus));
  make(NetworkBlock(eventBus: eventBus));
  make(PackageBlock(eventBus: eventBus));
  make(PermissionsBlock(eventBus: eventBus));
  make(RenameBlock(eventBus: eventBus));
  make(SymlinkBlock(eventBus: eventBus));
  make(SyncBlock(eventBus: eventBus));
  make(SystemdBlock(eventBus: eventBus));
  make(TemplateBlock(eventBus: eventBus));
  make(TouchBlock(eventBus: eventBus));
  make(ValidateBlock(eventBus: eventBus));

  // 3. For each record, look up the block by type, set properties from
  //    the record, and rollback.
  int rolledBack = 0;
  for (final record in targetRecords) {
    final block = actionBlockMap[record.blockType];
    if (block == null) {
      logger.warning(
        'Cannot rollback ${record.blockType}: '
        '${record.id.isNotEmpty
            ? record.id
            : record.source.isNotEmpty
            ? record.source
            : '<unknown>'} — '
        'unknown action type.',
      );
      continue;
    }

    block.resetState();
    block.id = record.id;
    block.source = record.source;
    block.destination = record.destination;
    block.sha256 = record.sha256;
    block.status = record.status;

    try {
      await block.rollback();
      rolledBack++;
    } catch (e) {
      logger.severe(
        'Rollback failed for ${record.blockType}: '
        '${record.id.isNotEmpty ? record.id : record.source} — $e',
      );
    }
  }

  // 4. Update the lockfile — remove the rolled-back records.
  final remainingRecords = allRecords
      .where(
        (r) => !targetRecords.any(
          (t) =>
              t.blockType == r.blockType &&
              t.id == r.id &&
              t.source == r.source &&
              t.destination == r.destination,
        ),
      )
      .toList();

  if (remainingRecords.isEmpty) {
    await lockMgr.delete();
    logger.info('Lockfile deleted — all blocks rolled back.');
  } else {
    await lockMgr.write(
      V2LockfileData(
        appliedBlocks: remainingRecords,
        configChecksum: lockData.configChecksum,
      ),
    );
    logger.info(
      'Lockfile updated — $rolledBack block(s) rolled back, '
      '${remainingRecords.length} remaining.',
    );
  }

  logger.info(
    'Rollback completed — $rolledBack/${targetRecords.length} blocks.',
  );
}

/// Parses a config file and collects action block metadata without executing
/// the blocks. Used by `diff`, `format`, and `status` commands for inspection.
///
/// Returns a list of [BlockSnapshot]s with their properties populated from the
/// config context, but without calling [ActionBlock.execute].
///
/// Snapshots are captured at parse time (per-block during processing) so each
/// entry reflects the correct block state — unlike a mutable ActionBlock
/// reference which would inherit the last block's state from the singleton.
Future<List<BlockSnapshot>> parseAndCollectBlocks(
  String configPath, {
  EventBus? eventBus,
  ConfigrPluginLoader? pluginLoader,
}) async {
  final fs = const LocalFileSystem();
  final configFile = fs.file(configPath);
  if (!await configFile.exists()) {
    throw ConfigFileNotFoundException(
      'Configuration file not found: ${configFile.path}',
    );
  }
  final snapshotCollector = await _parseConfigBlocks(
    configFile,
    eventBus: eventBus,
    pluginLoader: pluginLoader,
  );
  return snapshotCollector;
}

/// Registers all v2 block handlers on [processor] and any plugins.
///
/// Registers three layers:
/// 1. **Section handlers** (`ResourcesBlockHandler`, `ResourceBlockHandler`,
///    `ActionsBlockHandler`, etc.) so that nested v1-style configs (
///    `resource { actions { copy { … } } }`) navigate correctly with context
///    variable propagation.
/// 2. **ActionBlock subclasses** as global block handlers (so flat configs
///    like `copy { … }` work) AND as scoped handlers under `actions` (so
///    nested configs execute the real action blocks rather than collecting
///    old [Action] model objects).
/// 3. **Plugin blocks** after built-ins so plugins can override/extend.
///
/// If [pluginLoader] is provided, its [ConfigrPluginLoader.registerAllPlugins]
/// is called after built-in block registration so that plugins can override or
/// extend the built-in handlers.
Future<void> _registerAllBlocks(
  i3.ConfigProcessor processor, {
  EventBus? eventBus,
  bool dryRun = false,
  PrivilegeEscalation? privilegeEscalation,
  ConfigrPluginLoader? pluginLoader,
  String configDir = '.',
}) async {
  // -----------------------------------------------------------------------
  // 1. Create ActionBlock instances and inject dependencies
  // -----------------------------------------------------------------------
  ActionBlock make<T extends ActionBlock>(T block) {
    block.dryRun = dryRun;
    block.privilegeEscalation = privilegeEscalation;
    block.fileSystem ??= const LocalFileSystem();
    return block;
  }

  // Store processor reference so handlers (e.g. PluginBlockHandler)
  // can access it to register additional blocks during config processing.
  processor.context.options['_processor'] = processor;

  final actionBlockMap = <String, ActionBlock>{
    'backup': make(BackupBlock(eventBus: eventBus)),
    'compress': make(CompressBlock(eventBus: eventBus)),
    'copy': make(CopyBlock(eventBus: eventBus)),
    'decompress': make(DecompressBlock(eventBus: eventBus)),
    'delete': make(DeleteBlock(eventBus: eventBus)),
    'download': make(DownloadBlock(eventBus: eventBus)),
    'echo': make(EchoBlock(eventBus: eventBus)),
    'execute': make(ExecuteBlock(eventBus: eventBus)),
    'file': make(FileBlock(eventBus: eventBus)),
    'git': make(GitBlock(eventBus: eventBus)),
    'move': make(MoveBlock(eventBus: eventBus)),
    'network': make(NetworkBlock(eventBus: eventBus)),
    'package': make(PackageBlock(eventBus: eventBus)),
    'permissions': make(PermissionsBlock(eventBus: eventBus)),
    'rename': make(RenameBlock(eventBus: eventBus)),
    'symlink': make(SymlinkBlock(eventBus: eventBus)),
    'sync': make(SyncBlock(eventBus: eventBus)),
    'systemd': make(SystemdBlock(eventBus: eventBus)),
    'template': make(TemplateBlock(eventBus: eventBus)),
    'touch': make(TouchBlock(eventBus: eventBus)),
    'validate': make(ValidateBlock(eventBus: eventBus)),
  };

  // -----------------------------------------------------------------------
  // 2. Create a v2-aware ActionsBlockHandler that dispatches to real
  //    ActionBlock subclasses instead of the old ActionBlockHandler collectors.
  // -----------------------------------------------------------------------
  final v2ActionsHandler = ActionsBlockHandler(
    customActionHandlers: actionBlockMap,
  );

  // -----------------------------------------------------------------------
  // 3. Register section handlers with our custom actions handler injected
  // -----------------------------------------------------------------------
  // Create v2-aware resource handlers to pass to both global and scoped
  // registrations, so `resource { ... }` works both as a top-level block
  // AND nested under `resources { ... }`.
  final v2ResourceHandler = ResourceBlockHandler(
    customActionsHandler: v2ActionsHandler,
    eventBus: eventBus,
  );
  final v2FileHandler = InlineResourceTypeHandler(
    'file',
    customActionsHandler: v2ActionsHandler,
  );
  final v2DirectoryHandler = InlineResourceTypeHandler(
    'directory',
    customActionsHandler: v2ActionsHandler,
  );

  processor.registerBlockHandler(
    ResourcesBlockHandler(
      customResourceHandler: v2ResourceHandler,
      customFileHandler: v2FileHandler,
      customDirectoryHandler: v2DirectoryHandler,
    ),
  );
  processor.registerBlockHandler(v2ResourceHandler);
  processor.registerBlockHandler(v2FileHandler);
  processor.registerBlockHandler(v2DirectoryHandler);
  processor.registerBlockHandler(v2ActionsHandler);
  processor.registerBlockHandler(CommandsBlockHandler());
  processor.registerBlockHandler(PackagesBlockHandler());
  processor.registerBlockHandler(ScriptsBlockHandler('pre_apply_scripts'));
  processor.registerBlockHandler(ScriptsBlockHandler('post_apply_scripts'));
  processor.registerBlockHandler(TemplateBlockHandler());
  processor.registerBlockHandler(TemplateVarsBlockHandler());
  processor.registerBlockHandler(SubCommandsBlockHandler());
  processor.registerBlockHandler(CommandEntryBlockHandler());
  processor.registerBlockHandler(PackageEntryBlockHandler());

  // Register the plugin block handler so config files can declare plugins
  // via `plugin { lua = "..." }` blocks.
  if (pluginLoader != null) {
    processor.registerBlockHandler(
      PluginBlockHandler(
        processor: processor,
        pluginLoader: pluginLoader,
        configDir: configDir,
        eventBus: eventBus,
      ),
    );
  }

  // -----------------------------------------------------------------------
  // 4. Register all ActionBlocks as global handlers
  // -----------------------------------------------------------------------
  for (final block in actionBlockMap.values) {
    processor.registerBlockHandler(block);
  }

  // -----------------------------------------------------------------------
  // 5. Register plugin blocks after built-ins so plugins can override
  // -----------------------------------------------------------------------
  if (pluginLoader != null) {
    await pluginLoader.registerAllPlugins(processor, eventBus: eventBus);

    // Load individual plugin files (e.g. specified via --plugin CLI flag)
    if (pluginLoader.pluginFiles.isNotEmpty) {
      for (final filePath in pluginLoader.pluginFiles) {
        if (filePath.endsWith('.lua')) {
          final plugin = LuaPlugin(scriptPath: filePath);
          await plugin.initialize();
          plugin.registerBlocks(processor, eventBus: eventBus);
          pluginLoader.registerPlugin(plugin);
          logger.info('Loaded plugin file: $filePath');
        } else {
          logger.warning('Unsupported plugin file type: $filePath');
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Parse a config file and return the collected [BlockSnapshot]s
/// (dry-run mode — no execution).
///
/// Also populates [_actionBlocks] with mutable [ActionBlock] references
/// for use by tests that need to execute/rollback specific block types.
Future<List<BlockSnapshot>> _parseConfigBlocks(
  File configFile, {
  EventBus? eventBus,
  ConfigrPluginLoader? pluginLoader,
}) async {
  final contents = await configFile.readAsString();
  final config = i3.Config.parse(contents);
  final processor = i3.ConfigProcessor();
  // Mutable collector for tests.
  processor.context.options['_actionBlocks'] = <ActionBlock>[];
  // Snapshot collector for CLI consumers.
  final snapshots = <BlockSnapshot>[];
  processor.context.options['_blockSnapshots'] = snapshots;

  await _registerAllBlocks(
    processor,
    eventBus: eventBus,
    dryRun: true,
    pluginLoader: pluginLoader,
    configDir: p.dirname(configFile.path),
  );

  await processor.process(config);
  return snapshots;
}

/// SHA-256 hex digest of a string using `package:crypto`.
String _sha256Hex(String input) {
  final bytes = utf8.encode(input);
  return sha256.convert(bytes).toString();
}

/// Collects script paths from a `pre_apply_scripts` or `post_apply_scripts`
/// block in the parsed config AST.
///
/// Scripts can be specified as command arguments:
/// ```i3
/// pre_apply_scripts {
///   "setup.sh"
///   "check_env.sh"
/// }
/// ```
/// Returns the list of script paths/commands to execute.
List<String> _collectScriptsFromConfig(i3.Config config, String blockType) {
  final scripts = <String>[];
  for (final statement in config.statements) {
    if (statement is i3.Block && statement.blockType == blockType) {
      for (final element in statement.body) {
        switch (element) {
          case i3.Command cmd:
            for (final arg in cmd.args) {
              final raw = arg.toConfigString();
              if (raw.isNotEmpty) scripts.add(_unquote(raw));
            }
          case i3.Assignment assign:
            for (final v in assign.values) {
              final raw = v.toConfigString();
              if (raw.isNotEmpty) scripts.add(_unquote(raw));
            }
          default:
            break;
        }
      }
    }
  }
  return scripts;
}

String _unquote(String s) {
  if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
    return s.substring(1, s.length - 1);
  }
  return s;
}
