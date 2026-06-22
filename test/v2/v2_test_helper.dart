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
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/reader/handlers/configr_handlers.dart';
import 'package:configr/src/utils/file_utils.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:file/memory.dart';
import 'package:file/file.dart' show FileSystem;
import 'package:i3config/i3config_v2.dart' as i3;
import 'package:test/test.dart';

/// Test helper for v2 ActionBlock tests.
///
/// Parses i3config string configs and runs them through the v2 pipeline
/// against a [MemoryFileSystem] so tests are fast and hermetic.
///
/// In v2, blocks execute **during processing** via
/// [ActionBlock.afterChildrenProcessed]. The helper provides two modes:
///
/// - [processConfig] — dry-run mode: parses and processes the config but does
///   **not** execute the blocks. Use this to verify property parsing for
///   blocks that require real system access (execute, git, download, etc.).
/// - [runConfig] — full mode: processes AND executes each block. Use this for
///   blocks that work on the memory filesystem (copy, move, touch, etc.).
///
/// Usage:
/// ```dart
/// final helper = V2TestHelper();
/// await helper.runConfig('''
///   copy {
///     source = "/src/file.txt"
///     destination = "/dst/file.txt"
///   }
/// ''');
/// expect(await helper.fileExists('/dst/file.txt'), isTrue);
/// ```
class V2TestHelper {
  late final FileSystem fileSystem;
  late final EventBus eventBus;
  final List<ModuleEvent> emittedEvents = [];

  int _testIdCounter = 0;
  String nextId() => 'v2_test_${_testIdCounter++}';

  V2TestHelper() {
    fileSystem = MemoryFileSystem();
    eventBus = EventBus();
    eventBus.stream.listen(emittedEvents.add);

    fileSystem.currentDirectory = fileSystem.directory('/');
  }

  /// Creates a file at [path] with [content] in the memory filesystem.
  Future<void> createFile(String path, String content) {
    return FileUtils.writeFile(
      path,
      content,
      fileSystem: fileSystem,
      recursive: true,
    );
  }

  /// Creates a directory at [path] in the memory filesystem.
  Future<void> createDir(String path) {
    return FileUtils.createDirectory(
      path,
      fileSystem: fileSystem,
      recursive: true,
    );
  }

  /// Returns true if [path] exists and is a file.
  Future<bool> fileExists(String path) {
    return FileUtils.fileExists(path, fileSystem: fileSystem);
  }

  /// Returns true if [path] exists and is a directory.
  Future<bool> dirExists(String path) {
    return FileUtils.directoryExists(path, fileSystem: fileSystem);
  }

  /// Reads the content of [path].
  Future<String> readFile(String path) {
    return FileUtils.readFile(path, fileSystem: fileSystem);
  }

  /// Deletes [path].
  Future<void> deleteFile(String path) {
    return FileUtils.deleteFile(path, fileSystem: fileSystem);
  }

  /// Parses [configText] as i3config and processes it through the v2
  /// processor with all registered block handlers in **dry-run mode**.
  ///
  /// Blocks are parsed and their properties are read, but [ActionBlock.execute]
  /// is **not** called. Returns the collected [ActionBlock] instances for
  /// property verification.
  ///
  /// Use this for blocks that require real system access (execute, git,
  /// download, network, package, systemd, permissions).
  Future<List<ActionBlock>> processConfig(String configText) async {
    return _process(configText, dryRun: true);
  }

  /// Parses [configText] as i3config and runs it through the v2 processor
  /// with all registered block handlers in **full execution mode**.
  ///
  /// Each block executes as it is processed via
  /// [ActionBlock.afterChildrenProcessed]. Returns the collected
  /// [ActionBlock] instances for result assertions.
  ///
  /// Throws if any block's [execute] throws.
  Future<List<ActionBlock>> runConfig(String configText) async {
    return _process(configText, dryRun: false);
  }

  /// Like [runConfig] but also calls [ActionBlock.rollback] on each block
  /// (in reverse order) after processing completes.
  Future<List<ActionBlock>> runConfigWithRollback(String configText) async {
    final blocks = await runConfig(configText);
    // Rollback in reverse
    for (final block in blocks.reversed) {
      await block.rollback();
    }
    return blocks;
  }

  /// Internal: parses and processes [configText] with the given [dryRun]
  /// mode. Injects [fileSystem] into every block before processing so that
  /// execute() can use it.
  Future<List<ActionBlock>> _process(
    String configText, {
    required bool dryRun,
  }) async {
    final parsed = i3.Config.parse(configText);
    final processor = i3.ConfigProcessor();
    final actionBlocks = <ActionBlock>[];
    processor.context.options['_actionBlocks'] = actionBlocks;

    _registerAllBlocks(processor, dryRun: dryRun);

    await processor.process(parsed);

    return actionBlocks;
  }

  void _registerAllBlocks(i3.ConfigProcessor processor, {bool dryRun = false}) {
    // -----------------------------------------------------------------------
    // 1. Create ActionBlock instances, inject filesystem and dryRun
    // -----------------------------------------------------------------------
    ActionBlock make<T extends ActionBlock>(T block) {
      block.fileSystem = fileSystem;
      block.dryRun = dryRun;
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
    // 2. Create v2-aware ActionsBlockHandler
    // -----------------------------------------------------------------------
    final v2ActionsHandler = ActionsBlockHandler(
      customActionHandlers: actionBlockMap,
    );

    // -----------------------------------------------------------------------
    // 3. Register section handlers
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
    // 4. Register all ActionBlocks as global handlers
    // -----------------------------------------------------------------------
    for (final block in actionBlockMap.values) {
      processor.registerBlockHandler(block);
    }
  }

  /// Clears the emitted events list for a fresh start.
  void clearEvents() => emittedEvents.clear();

  /// Returns the first [ModuleEvent] of type [T] that was emitted, or null.
  T? eventOfType<T extends ModuleEvent>() {
    for (final e in emittedEvents) {
      if (e is T) return e;
    }
    return null;
  }

  /// Asserts that an event of type [T] was emitted.
  void expectEvent<T extends ModuleEvent>() {
    expect(eventOfType<T>(), isNotNull, reason: 'Expected $T to be emitted');
  }
}
