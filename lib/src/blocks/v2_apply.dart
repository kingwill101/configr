import 'dart:convert';
import 'dart:io' as io;

import 'package:crypto/crypto.dart' show sha256;
import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/blocks/backup_block.dart';
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
import 'package:configr/src/plugins/configr_plugin.dart';
import 'package:configr/src/reader/handlers/configr_handlers.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:configr/src/utils/v2_lockfile_manager.dart';

import 'package:file/local.dart';
import 'package:i3config/i3config_v2.dart' as i3;

/// Applies a config file using the v2 ActionBlock pipeline.
///
/// Bypasses the old [ConfigManager]/[ResourceModule] path entirely.
/// Instead:
/// 1. Reads and parses the config file via `i3.Config.parse()`
/// 2. Creates a [i3.ConfigProcessor] and registers v2 block handlers
/// 3. Processes the parsed config — each block executes as it is processed
/// 4. Writes a lockfile so [rollbackV2] knows what was applied
Future<void> applyV2(
  String configPath, {
  EventBus? eventBus,
  bool force = false,
  ConfigrPluginLoader? pluginLoader,
}) async {
  // 1. Read the config file
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

  // 2. Parse via i3config v2
  final config = i3.Config.parse(contents);

  // 3. Create processor and register block handlers + plugins
  final processor = i3.ConfigProcessor();
  final appliedBlocks = <AppliedBlockRecord>[];
  processor.context.options['_appliedBlocks'] = appliedBlocks;

  await _registerAllBlocks(
    processor,
    eventBus: eventBus,
    pluginLoader: pluginLoader,
  );

  // 4. Process — each block executes as it is processed
  await processor.process(config);

  // 5. Check for errors collected during processing.
  // The processor catches all exceptions from handlers, so we track
  // failures via the '_errors' list in context options.
  final errors =
      (processor.context.options['_errors'] as List<Object>?) ?? <Object>[];

  if (errors.isNotEmpty) {
    logger.severe(
      'Apply failed — ${errors.length} block(s) encountered errors.',
    );
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

  // 6. Write lockfile with records of what was applied
  if (appliedBlocks.isNotEmpty) {
    final checksum = _sha256Hex(contents);
    final lockMgr = V2LockfileManager(
      V2LockfileManager.lockPathFor(configPath),
      fileSystem: fs,
    );
    await lockMgr.write(
      V2LockfileData(appliedBlocks: appliedBlocks, configChecksum: checksum),
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
Future<void> rollbackV2(
  String configPath, {
  EventBus? eventBus,
  int? count,
  ConfigrPluginLoader? pluginLoader,
}) async {
  final fs = const LocalFileSystem();

  // 1. Read the lockfile
  final lockMgr = V2LockfileManager(
    V2LockfileManager.lockPathFor(configPath),
    fileSystem: fs,
  );
  final lockData = await lockMgr.read();

  final allRecords = lockData.appliedBlocks;
  if (allRecords.isEmpty) {
    logger.info('Nothing to rollback — lockfile is empty.');
    return;
  }

  final targetRecords = count != null && count < allRecords.length
      ? allRecords.reversed.take(count).toList()
      : allRecords.reversed.toList();

  logger.info(
    'Rolling back ${targetRecords.length} block(s) from lockfile '
    '(${allRecords.length} total recorded).',
  );

  // 2. Build the same ActionBlock map used during apply so we can look up
  //    block instances by type.  This avoids re-parsing the config.
  final actionBlockMap = <String, ActionBlock>{};
  ActionBlock make<T extends ActionBlock>(T block) {
    block.fileSystem ??= fs;
    actionBlockMap[block.blockType] = block;
    return block;
  }

  // Only build the map — we don't register or process anything.
  // The instances just need their rollback() method.
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

    // Configure the instance from the lockfile record.
    // This is more reliable than re-parsing because singleton instances
    // lose per-occurrence state.
    block.resetState();
    block.id = record.id;
    block.source = record.source;
    block.destination = record.destination;
    block.sha256 = record.sha256;
    block.status = record.status;

    logger.info(
      'Rolling back ${record.blockType}: '
      '${record.id.isNotEmpty
          ? record.id
          : record.source.isNotEmpty
          ? record.source
          : record.blockType}',
    );
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
/// Returns a list of [ActionBlock]s with their properties populated from the
/// config context, but without calling [ActionBlock.execute].
Future<List<ActionBlock>> parseAndCollectBlocks(
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
  return _parseConfigBlocks(
    configFile,
    eventBus: eventBus,
    pluginLoader: pluginLoader,
  );
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
  ConfigrPluginLoader? pluginLoader,
}) async {
  // -----------------------------------------------------------------------
  // 1. Create ActionBlock instances and inject dependencies
  // -----------------------------------------------------------------------
  ActionBlock make<T extends ActionBlock>(T block) {
    block.dryRun = dryRun;
    block.fileSystem ??= const LocalFileSystem();
    return block;
  }

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
  processor.registerBlockHandler(ResourcesBlockHandler());
  processor.registerBlockHandler(
    ResourceBlockHandler(customActionsHandler: v2ActionsHandler),
  );
  processor.registerBlockHandler(
    InlineResourceTypeHandler('file', customActionsHandler: v2ActionsHandler),
  );
  processor.registerBlockHandler(
    InlineResourceTypeHandler(
      'directory',
      customActionsHandler: v2ActionsHandler,
    ),
  );
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

  // -----------------------------------------------------------------------
  // 4. Register all ActionBlocks as global handlers (registerScopedCommands
  //    is triggered here for flat configs)
  // -----------------------------------------------------------------------
  for (final block in actionBlockMap.values) {
    processor.registerBlockHandler(block);
  }

  // -----------------------------------------------------------------------
  // 5. Register plugin blocks after built-ins so plugins can override
  // -----------------------------------------------------------------------
  if (pluginLoader != null) {
    await pluginLoader.registerAllPlugins(processor, eventBus: eventBus);
  }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Parse a config file and return the collected [ActionBlock] instances
/// (dry-run mode — no execution).
Future<List<ActionBlock>> _parseConfigBlocks(
  io.File configFile, {
  EventBus? eventBus,
  ConfigrPluginLoader? pluginLoader,
}) async {
  final contents = await configFile.readAsString();
  final config = i3.Config.parse(contents);
  final processor = i3.ConfigProcessor();
  final actionBlocks = <ActionBlock>[];
  processor.context.options['_actionBlocks'] = actionBlocks;

  await _registerAllBlocks(
    processor,
    eventBus: eventBus,
    dryRun: true,
    pluginLoader: pluginLoader,
  );

  await processor.process(config);
  return actionBlocks;
}

/// SHA-256 hex digest of a string using `package:crypto`.
String _sha256Hex(String input) {
  final bytes = utf8.encode(input);
  return sha256.convert(bytes).toString();
}
