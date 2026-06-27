import 'dart:convert';
import 'dart:io';

import 'package:configr/src/cli/ui/handlers/base_handler.dart';
import 'package:configr/src/configr_directories.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/hooks/hook_manager.dart';
import 'package:configr/src/plugins/configr_plugin.dart';
import 'package:configr/src/plugins/lua_plugin.dart';
import 'package:configr/src/reader/handlers/configr_handlers.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:configr/src/utils/ssh_execution_service.dart';
import 'package:configr/src/utils/system_info.dart';
import 'package:configr/src/utils/v2_lockfile_manager.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:path/path.dart' as p;
import 'package_managers/package_manger.dart';
import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/blocks/alternatives_block.dart';
import 'package:configr/src/blocks/assert_block.dart';
import 'package:configr/src/blocks/authorized_key_block.dart';
import 'package:configr/src/blocks/backup_block.dart';
import 'package:configr/src/blocks/connection_block.dart';
import 'package:configr/src/multi_host/inventory_block.dart';
import 'package:configr/src/multi_host/inventory.dart';
import 'package:configr/src/multi_host/target_resolver.dart';
import 'package:configr/src/blocks/blockinfile_block.dart';
import 'package:configr/src/blocks/compress_block.dart';
import 'package:configr/src/blocks/copy_block.dart';
import 'package:configr/src/blocks/cron_block.dart';
import 'package:configr/src/blocks/debug_block.dart';
import 'package:configr/src/blocks/decompress_block.dart';
import 'package:configr/src/blocks/delete_block.dart';
import 'package:configr/src/blocks/download_block.dart';
import 'package:configr/src/blocks/dynamic_block.dart';
import 'package:configr/src/blocks/echo_block.dart';
import 'package:configr/src/blocks/execute_block.dart';
import 'package:configr/src/blocks/fail_block.dart';
import 'package:configr/src/blocks/fetch_block.dart';
import 'package:configr/src/blocks/file_block.dart';
import 'package:configr/src/blocks/firewalld_block.dart';
import 'package:configr/src/blocks/gather_facts_block.dart';
import 'package:configr/src/blocks/git_block.dart';
import 'package:configr/src/blocks/group_block.dart';
import 'package:configr/src/blocks/hostname_block.dart';
import 'package:configr/src/blocks/known_hosts_block.dart';
import 'package:configr/src/blocks/lineinfile_block.dart';
import 'package:configr/src/blocks/locale_gen_block.dart';
import 'package:configr/src/blocks/mount_block.dart';
import 'package:configr/src/blocks/move_block.dart';
import 'package:configr/src/blocks/network_block.dart';
import 'package:configr/src/blocks/package_block.dart';
import 'package:configr/src/blocks/pause_block.dart';
import 'package:configr/src/blocks/permissions_block.dart';
import 'package:configr/src/blocks/raw_block.dart';
import 'package:configr/src/blocks/rename_block.dart';
import 'package:configr/src/blocks/secrets_block.dart';
import 'package:configr/src/blocks/replace_block.dart';
import 'package:configr/src/blocks/script_block.dart';
import 'package:configr/src/blocks/service_block.dart';
import 'package:configr/src/blocks/set_fact_block.dart';
import 'package:configr/src/blocks/slurp_block.dart';
import 'package:configr/src/blocks/stat_block.dart';
import 'package:configr/src/blocks/symlink_block.dart';
import 'package:configr/src/blocks/sync_block.dart';
import 'package:configr/src/blocks/sysctl_block.dart';
import 'package:configr/src/blocks/systemd_block.dart';
import 'package:configr/src/blocks/template_block.dart';
import 'package:configr/src/blocks/timezone_block.dart';
import 'package:configr/src/blocks/touch_block.dart';
import 'package:configr/src/blocks/ufw_block.dart';
import 'package:configr/src/blocks/unarchive_block.dart';
import 'package:configr/src/blocks/uri_block.dart';
import 'package:configr/src/blocks/user_block.dart';
import 'package:configr/src/blocks/validate_block.dart';
import 'package:configr/src/blocks/wait_for_block.dart';
import 'package:configr/src/di.dart';
import 'package:configr/src/models/v2_lockfile_data.dart';
import 'package:configr/src/utils/command_runner.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:configr/src/utils/execution_service.dart';
import 'package:configr/src/utils/file_service.dart';
import 'package:configr/src/utils/privilege_escalation.dart';
import 'package:file/file.dart' show FileSystem;
import 'package:file/local.dart' show LocalFileSystem;
import 'package:i3config/i3config_v2.dart' as i3;

import '../reader/handlers/plugin_block_handler.dart';

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
///
/// If [connectionConfig] is provided (with a non-empty `host` key), all
/// operations run over SSH via [SSHExecutionService].
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
  Map<String, dynamic>? connectionConfig,
  List<String>? hosts,
  List<String>? roles,
  List<String>? groups,
  String strategy = 'linear',
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
    final confirmed =
        uiHandler?.confirm(
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
    logger.debug('Config contents:\n$contents');
  }

  // Execute pre-apply scripts before processing action blocks
  if (!dryRun) {
    final preScripts = _collectScriptsFromConfig(config, 'pre_apply_scripts');
    for (final script in preScripts) {
      logger.info('Executing pre-apply script: $script');
      try {
        final exec = di.isRegistered<ExecutionService>()
            ? di<ExecutionService>()
            : const LocalExecutionService();
        await exec.run(
          '/bin/sh',
          ['-c', script],
          workingDirectory: fs.currentDirectory.path,
        );
      } catch (e) {
        logger.warning('Pre-apply script failed: $script — $e');
      }
    }
  }

  final configDir = p.dirname(p.absolute(configPath));

  // Create processor with a filesystem that resolves includes relative to the
  // config file's directory, and expose built-in system variables
  // (os, host, user, date, env) plus $cwd so configs can reference them.
  final processor = i3.ConfigProcessor(
    fileSystem: _ConfigrFileSystem(configDir),
  );

  // Discover .configr/ directory alongside the config file
  final dotConfigrPath = p.join(configDir, '.configr');
  final configrDirs = ConfigrDirectories(projectConfigrPath: dotConfigrPath);

  // Set all built-in variables on the processor context
  SystemInfo(
    configDir: configDir,
    configrVersion: '1.0.0',
    configrCacheDir: configrDirs.cacheDir,
    configrBackupDir: configrDirs.backupDir,
  ).applyToContext(processor.context);

  final appliedBlocks = <AppliedBlockRecord>[];
  processor.context.options['_appliedBlocks'] = appliedBlocks;
  if (failFast) {
    processor.context.options['_failFast'] = true;
  }

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

  // Initialize hook manager for .configr/hooks/ directory
  final hooksDir = p.join(dotConfigrPath, 'hooks');
  final hookMgr = HookManager(hooksDir: hooksDir);
  processor.context.options['_hookManager'] = hookMgr;

  await _registerAllBlocks(
    processor,
    eventBus: eventBus,
    dryRun: dryRun,
    privilegeEscalation: privilegeEscalation,
    pluginLoader: pluginLoader,
    configDir: configDir,
    connectionConfig: connectionConfig,
  );

  // Invoke plugin onConfigLoad hooks
  if (pluginLoader != null) {
    final plugins = await pluginLoader.discoverPlugins();
    for (final plugin in plugins) {
      await plugin.onConfigLoad(config);
    }
  }

  // Run pre-apply hook before processing blocks
  await hookMgr.runEvent('pre-apply', extraVars: {
    'config_path': configPath,
  });

  // Process — each block executes as it is processed
  await processor.process(config);

  // Resolve targets from inventory if multi-host flags were provided
  final inventory =
      processor.context.globalContext.options['_inventory'] as Inventory?;
  final hasMultiHostFlags =
      (hosts != null && hosts.isNotEmpty) ||
      (roles != null && roles.isNotEmpty) ||
      (groups != null && groups.isNotEmpty);
  if (inventory != null && hasMultiHostFlags) {
    final resolver = TargetResolver();
    final resolved = resolver.resolve(
      hosts: hosts,
      roles: roles,
      groups: groups,
      inventory: inventory,
    );
    logger.info(
      'Targeted ${resolved.length} host(s): '
      '${resolved.map((h) => h.name).join(', ')} '
      '(strategy: $strategy)',
    );
  }

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
        final exec = di.isRegistered<ExecutionService>()
            ? di<ExecutionService>()
            : const LocalExecutionService();
        await exec.run(
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
    // Run on-error hook before reporting failure
    await hookMgr.runEvent('on-error', extraVars: {
      'config_path': configPath,
      'error_count': errors.length.toString(),
    });

    logger.error(
      'Apply failed — ${errors.length} block(s) encountered errors:',
    );
    for (final err in errors) {
      final location = err.source != null ? ' (${err.source})' : '';
      logger.error('  - ${err.blockType}: ${err.message}$location');
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

  // Run post-apply hook after successful processing
  await hookMgr.runEvent('post-apply', extraVars: {
    'config_path': configPath,
    'block_count': appliedBlocks.length.toString(),
  });

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

  // 2. Register DI dependencies and build the same ActionBlock map used
  //    during apply so we can look up block instances by type.
  di
    ..allowReassignment = true
    ..registerSingleton<DryRunFlag>(DryRunFlag(false))
    ..registerSingleton<EventBus>(eventBus ?? EventBus())
    ..registerSingleton<PrivilegeEscalation>(NonInteractiveSudoEscalation())
    ..registerSingleton<FileSystem>(fs)
    ..allowReassignment = false;

  final actionBlockMap = <String, ActionBlock>{
    'alternatives': AlternativesBlock(),
    'apt': AptBlock(),
    'authorized_key': AuthorizedKeyBlock(),
    'backup': BackupBlock(),
    'blockinfile': BlockInFileBlock(),
    'brew': BrewBlock(),
    'compress': CompressBlock(),
    'copy': CopyBlock(),
    'cron': CronBlock(),
    'debug': DebugBlock(),
    'decompress': DecompressBlock(),
    'delete': DeleteBlock(),
    'dnf': DnfBlock(),
    'docker': DockerBlock(),
    'download': DownloadBlock(),
    'echo': EchoBlock(),
    'execute': ExecuteBlock(),
    'fail': FailBlock(),
    'fetch': FetchBlock(),
    'file': FileBlock(),
    'firewalld': FirewalldBlock(),
    'flatpak': FlatpakBlock(),
    'gather_facts': GatherFactsBlock(),
    'git': GitBlock(),
    'group': GroupBlock(),
    'hostname': HostnameBlock(),
    'known_hosts': KnownHostsBlock(),
    'lineinfile': LineInFileBlock(),
    'locale_gen': LocaleGenBlock(),
    'mount': MountBlock(),
    'move': MoveBlock(),
    'network': NetworkBlock(),
    'npm': NpmBlock(),
    'package': PackageBlock(),
    'pacman': PacmanBlock(),
    'pamac': PamacBlock(),
    'pause': PauseBlock(),
    'permissions': PermissionsBlock(),
    'pip': PipBlock(),
    'raw': RawBlock(),
    'rename': RenameBlock(),
    'replace': ReplaceBlock(),
    'script': ScriptBlock(),
    'service': ServiceBlock(),
    'set_fact': SetFactBlock(),
    'slurp': SlurpBlock(),
    'snap': SnapBlock(),
    'stat': StatBlock(),
    'symlink': SymlinkBlock(),
    'sync': SyncBlock(),
    'sysctl': SysctlBlock(),
    'systemd': SystemdBlock(),
    'template': TemplateBlock(),
    'timezone': TimezoneBlock(),
    'touch': TouchBlock(),
    'ufw': UfwBlock(),
    'unarchive': UnarchiveBlock(),
    'uri': UriBlock(),
    'user': UserBlock(),
    'validate': ValidateBlock(),
    'wait_for': WaitForBlock(),
    'yum': YumBlock(),
  };

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
      logger.error(
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

/// Processes a config file and returns the resolved state for display.
///
/// Runs the full pipeline (including secret resolution) and returns the
/// resolved variables, registered blocks, and sensitive-key tracking so
/// the caller can display the fully-resolved configuration.
///
/// Returns null if the config file cannot be parsed.
Future<ResolvedConfig?> resolveConfigBlocks(
  String configPath, {
  EventBus? eventBus,
  ConfigrPluginLoader? pluginLoader,
}) async {
  final fs = const LocalFileSystem();
  final configFile = fs.file(configPath);
  if (!await configFile.exists()) return null;

  final contents = await configFile.readAsString();
  final config = i3.Config.parse(contents);
  final configDir = p.dirname(p.absolute(configPath));
  final dotConfigrPath = p.join(configDir, '.configr');
  final configrDirs = ConfigrDirectories(projectConfigrPath: dotConfigrPath);

  final processor = i3.ConfigProcessor(
    fileSystem: _ConfigrFileSystem(configDir),
  );

  SystemInfo(
    configDir: configDir,
    configrVersion: '1.0.0',
    configrCacheDir: configrDirs.cacheDir,
    configrBackupDir: configrDirs.backupDir,
  ).applyToContext(processor.context);

  final hookMgr = HookManager(hooksDir: p.join(dotConfigrPath, 'hooks'));
  processor.context.options['_hookManager'] = hookMgr;

  await _registerAllBlocks(
    processor,
    eventBus: eventBus,
    dryRun: true,
    pluginLoader: pluginLoader,
    configDir: configDir,
  );

  await processor.process(config);

  final globalCtx = processor.context.globalContext;

  // Collect resolved variables (excluding internal _-prefixed ones)
  final variables = <String, String>{};
  for (final entry in globalCtx.variables.entries) {
    if (!entry.key.startsWith('_')) {
      variables[entry.key] = entry.value.toString();
    }
  }

  // Collect sensitive key names for redaction
  final sensitiveKeys =
      (globalCtx.options['_sensitiveKeys'] as Set<String>?) ?? {};

  return ResolvedConfig(
    config: config,
    variables: variables,
    sensitiveKeys: sensitiveKeys,
    blockRegistry: Map.from(globalCtx.blockRegistry),
  );
}

/// The resolved state of a configuration after processing.
class ResolvedConfig {
  final i3.Config config;
  final Map<String, String> variables;
  final Set<String> sensitiveKeys;
  final Map<String, Map<String?, Map<String, dynamic>>> blockRegistry;

  const ResolvedConfig({
    required this.config,
    required this.variables,
    required this.sensitiveKeys,
    required this.blockRegistry,
  });
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
///
/// If [connectionConfig] is provided (with a non-empty `host` key), an
/// [SSHExecutionService] is used instead of [LocalExecutionService].
Future<void> _registerAllBlocks(
  i3.ConfigProcessor processor, {
  EventBus? eventBus,
  bool dryRun = false,
  PrivilegeEscalation? privilegeEscalation,
  ConfigrPluginLoader? pluginLoader,
  String configDir = '.',
  Map<String, dynamic>? connectionConfig,
}) async {
  // -----------------------------------------------------------------------
  // 1. Register DI dependencies before creating blocks
  // -----------------------------------------------------------------------
  ExecutionService executionService;
  if (connectionConfig != null &&
      connectionConfig['host'] is String &&
      (connectionConfig['host'] as String).isNotEmpty) {
    final ssh = SSHExecutionService();
    await ssh.connect(connectionConfig);
    executionService = ssh;
  } else {
    executionService = const LocalExecutionService();
  }

  di
    ..allowReassignment = true
    ..registerSingleton<DryRunFlag>(DryRunFlag(dryRun))
    ..registerSingleton<EventBus>(eventBus ?? EventBus())
    ..registerSingleton<PrivilegeEscalation>(
      privilegeEscalation ?? NonInteractiveSudoEscalation(),
    )
    ..registerSingleton<FileSystem>(const LocalFileSystem())
    ..registerSingleton<ExecutionService>(executionService)
    ..registerSingleton<FileService>(LocalFileService())
    ..registerSingleton<CommandRunner>(const LocalCommandRunner())
    ..allowReassignment = false;

  // Store processor reference so handlers (e.g. PluginBlockHandler)
  // can access it to register additional blocks during config processing.
  processor.context.options['_processor'] = processor;
  processor.context.options['_dryRun'] = dryRun;

  final actionBlockMap = <String, ActionBlock>{
    'alternatives': AlternativesBlock(),
    'apt': AptBlock(),
    'assert': AssertBlock(),
    'authorized_key': AuthorizedKeyBlock(),
    'backup': BackupBlock(),
    'blockinfile': BlockInFileBlock(),
    'brew': BrewBlock(),
    'compress': CompressBlock(),
    'copy': CopyBlock(),
    'cron': CronBlock(),
    'debug': DebugBlock(),
    'decompress': DecompressBlock(),
    'delete': DeleteBlock(),
    'dnf': DnfBlock(),
    'docker': DockerBlock(),
    'download': DownloadBlock(),
    'echo': EchoBlock(),
    'execute': ExecuteBlock(),
    'fail': FailBlock(),
    'fetch': FetchBlock(),
    'file': FileBlock(),
    'firewalld': FirewalldBlock(),
    'flatpak': FlatpakBlock(),
    'gather_facts': GatherFactsBlock(),
    'git': GitBlock(),
    'group': GroupBlock(),
    'hostname': HostnameBlock(),
    'known_hosts': KnownHostsBlock(),
    'lineinfile': LineInFileBlock(),
    'locale_gen': LocaleGenBlock(),
    'mount': MountBlock(),
    'move': MoveBlock(),
    'network': NetworkBlock(),
    'npm': NpmBlock(),
    'package': PackageBlock(),
    'pacman': PacmanBlock(),
    'pamac': PamacBlock(),
    'pause': PauseBlock(),
    'permissions': PermissionsBlock(),
    'pip': PipBlock(),
    'raw': RawBlock(),
    'rename': RenameBlock(),
    'replace': ReplaceBlock(),
    'script': ScriptBlock(),
    'service': ServiceBlock(),
    'set_fact': SetFactBlock(),
    'slurp': SlurpBlock(),
    'snap': SnapBlock(),
    'stat': StatBlock(),
    'symlink': SymlinkBlock(),
    'sync': SyncBlock(),
    'sysctl': SysctlBlock(),
    'systemd': SystemdBlock(),
    'timezone': TimezoneBlock(),
    'touch': TouchBlock(),
    'ufw': UfwBlock(),
    'unarchive': UnarchiveBlock(),
    'uri': UriBlock(),
    'user': UserBlock(),
    'validate': ValidateBlock(),
    'wait_for': WaitForBlock(),
    'yum': YumBlock(),
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
  final v2TemplateHandler = TemplateBlock();
  final v2ResourceHandler = ResourceBlockHandler(
    customActionsHandler: v2ActionsHandler,
    customTemplateHandler: v2TemplateHandler,
    eventBus: eventBus,
  );
  final v2FileHandler = InlineResourceTypeHandler(
    'file',
    customActionsHandler: v2ActionsHandler,
    customTemplateHandler: v2TemplateHandler,
  );
  final v2DirectoryHandler = InlineResourceTypeHandler(
    'directory',
    customActionsHandler: v2ActionsHandler,
    customTemplateHandler: v2TemplateHandler,
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
  processor.registerBlockHandler(DynamicBlockHandler());

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
  // TemplateBlock is not in actionBlockMap (it's not a child of `actions`),
  // but it needs a global registration for standalone template blocks.
  processor.registerBlockHandler(v2TemplateHandler);

  // -----------------------------------------------------------------------
  // 5. Register SecretsBlock for secret resolution
  // -----------------------------------------------------------------------
  processor.registerBlockHandler(SecretsBlock());

  // -----------------------------------------------------------------------
  // 6. Register ConnectionBlock for inline SSH connection config
  // -----------------------------------------------------------------------
  processor.registerBlockHandler(ConnectionBlock());

  // -----------------------------------------------------------------------
  // 7. Register InventoryBlock for multi-host inventory configuration
  // -----------------------------------------------------------------------
  processor.registerBlockHandler(InventoryBlock());

  // -----------------------------------------------------------------------
  // 8. Register plugin blocks after built-ins so plugins can override
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
  final configDir = p.dirname(configFile.path);
  final processor = i3.ConfigProcessor(
    fileSystem: _ConfigrFileSystem(configDir),
  );

  // Set built-in system variables for the dry-run preview too
  SystemInfo(configDir: configDir).applyToContext(processor.context);

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

/// Custom i3config [FileSystem] that resolves include paths relative to the
/// config file's directory instead of the process working directory.
///
/// Absolute paths and virtual files are passed through unchanged.
class _ConfigrFileSystem implements i3.FileSystem {
  final String configDir;
  const _ConfigrFileSystem(this.configDir);

  @override
  Future<String?> readFile(String path) async {
    final resolved = p.isAbsolute(path)
        ? path
        : p.normalize(p.join(configDir, path));
    return const i3.PhysicalFileSystem().readFile(resolved);
  }
}
