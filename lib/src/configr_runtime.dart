import 'dart:io' as io;

import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/blocks/v2_apply.dart';
import 'package:configr/src/cli/ui/handlers/base_handler.dart';
import 'package:configr/src/configr_config.dart';
import 'package:configr/src/format/config_source.dart';
import 'package:configr/src/format/format_service.dart';
import 'package:configr/src/multi_host/inventory.dart';
import 'package:configr/src/multi_host/inventory_block.dart';
import 'package:configr/src/multi_host/host_rollback.dart' as host_rollback;
import 'package:configr/src/models/command.dart';
import 'package:configr/src/models/config.dart';
import 'package:configr/src/reader/config_builder.dart';
import 'package:configr/src/reader/handlers/configr_handlers.dart';
import 'package:configr/src/utils/command_executor.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:configr/src/utils/execution_service.dart'
    hide CommandOutputHandler;
import 'package:configr/src/utils/privilege_escalation.dart';
import 'package:configr/src/utils/ssh_execution_service.dart';
import 'package:file/file.dart';
import 'package:i3config/i3config_v2.dart' as i3;
import 'package:path/path.dart' as p;

/// Lightweight runtime for v2 Configr operations.
///
/// Wraps [ConfigrConfig] and provides convenience methods that CLI commands
/// commonly need (resolving config paths, running v2 apply/rollback/parse).
///
/// This is the library-entry boundary for the v2 pipeline.  CLI commands
/// receive a [ConfigrRuntime] instead of reaching into [ConfigManager]
/// internals.
class ConfigrRuntime {
  final ConfigrConfig config;

  ConfigrRuntime(this.config);

  /// The file system from config.
  FileSystem get fileSystem => config.fileSystem;

  /// The UI handler from config.
  UIHandler? get uiHandler => config.uiHandler as UIHandler?;

  /// The event bus from config.
  EventBus get eventBus => config.eventBus;

  /// The format service for reading/writing config files.
  FormatService get formatService => config.formatService;

  /// The current working directory used as a base for relative paths.
  String get workingDirectory =>
      config.localPath ?? fileSystem.currentDirectory.path;

  /// Resolves the config file path, defaulting to `<workingDirectory>/config`.
  String get resolvedConfigPath =>
      config.configPath ?? p.join(workingDirectory, 'config');

  /// The [ConfigSource] for the resolved config path.
  ConfigSource get configSource =>
      ConfigSource.fromPath(resolvedConfigPath, fileSystem: fileSystem);

  /// The [ConfigSink] for the resolved config path.
  ConfigSink get configSink =>
      ConfigSink.fromPath(resolvedConfigPath, fileSystem: fileSystem);

  // ---------------------------------------------------------------------------
  // v2 pipeline entry points
  // ---------------------------------------------------------------------------

  /// Apply the config using the v2 ActionBlock pipeline.
  Future<void> apply({
    bool force = false,
    bool dryRun = false,
    bool failFast = false,
    bool interactive = false,
    bool verbose = false,
    bool debug = false,
    List<String>? hosts,
    List<String>? roles,
    List<String>? groups,
    String strategy = 'linear',
    Map<String, String>? extraVars,
  }) => applyV2(
    resolvedConfigPath,
    eventBus: eventBus,
    force: force,
    dryRun: dryRun,
    failFast: failFast,
    interactive: interactive,
    verbose: verbose,
    debug: debug,
    uiHandler: uiHandler,
    privilegeEscalation: config.privilegeEscalation,
    pluginLoader: config.pluginLoader,
    connectionConfig: config.connectionConfig?.toMap(),
    hosts: hosts,
    roles: roles,
    groups: groups,
    strategy: strategy,
    extraVars: extraVars,
  );

  /// Rollback applied blocks.
  Future<void> rollback({int? count, bool dryRun = false}) => rollbackV2(
    resolvedConfigPath,
    eventBus: eventBus,
    count: count,
    dryRun: dryRun,
    pluginLoader: config.pluginLoader,
  );

  /// Rollback applied blocks for a specific host.
  Future<int> rollbackHost({
    required String hostName,
    int? count,
    bool dryRun = false,
  }) async {
    final connectionConfig =
        config.connectionConfig?.toMap() ??
        await _inventoryConnectionConfig(hostName);

    return host_rollback.rollbackHost(
      configPath: resolvedConfigPath,
      hostName: hostName,
      count: count,
      dryRun: dryRun,
      fileSystem: fileSystem,
      connectionConfig: connectionConfig,
    );
  }

  Future<Map<String, dynamic>?> _inventoryConnectionConfig(
    String hostName,
  ) async {
    if (!await fileSystem.file(resolvedConfigPath).exists()) return null;

    final parsed = await readConfig();
    final processor = i3.ConfigProcessor();
    processor.registerBlockHandler(InventoryBlock());
    await processor.process(parsed);

    final inventory =
        processor.context.globalContext.options['_inventory'] as Inventory?;
    return inventory?.getHost(hostName)?.toConnectionMap();
  }

  /// Parse and collect block snapshots without executing them.
  Future<List<BlockSnapshot>> parseAndCollect() => parseAndCollectBlocks(
    resolvedConfigPath,
    eventBus: eventBus,
    pluginLoader: config.pluginLoader,
  );

  /// Resolve the full config (variables expanded, secrets fetched) and return
  /// a `ResolvedConfig` with the parsed AST, resolved variables, and
  /// sensitive-key tracking.
  Future<ResolvedConfig?> resolveConfig() => resolveConfigBlocks(
    resolvedConfigPath,
    eventBus: eventBus,
    pluginLoader: config.pluginLoader,
  );

  /// Read and parse the config file through the format service.
  Future<i3.Config> readConfig() => formatService.readConfig(configSource);

  /// Read the config into the structured Configr domain model.
  ///
  /// This path is used by CLI features that operate on model sections such as
  /// `commands { ... }` instead of executing action blocks.
  Future<Config> readStructuredConfig() async {
    final builder = ConfigBuilder();
    final configDir = p.dirname(p.absolute(resolvedConfigPath));
    final processor = createConfigrProcessor(
      builder,
      fileSystem: _ConfigrIncludeFileSystem(configDir),
    );

    await processor.process(await readConfig());
    return builder.build();
  }

  /// Run a top-level command from the `commands { ... }` section.
  Future<io.ProcessResult> runNamedCommand(
    String name, {
    List<String> extraArgs = const [],
    String? commandWorkingDirectory,
    bool runInShell = false,
    CommandOutputHandler? onOutput,
  }) async {
    final structured = await readStructuredConfig();
    final matches = structured.commands.where(
      (candidate) => candidate.name == name,
    );
    final command = matches.isEmpty ? null : matches.first;

    if (command == null) {
      throw ArgumentError('No command named "$name" found in config.');
    }

    final executionService = await _executionServiceForCommand();
    try {
      return await CommandExecutor.execute(
        Command(
          name: command.name,
          id: command.id,
          command: command.command,
          parameters: [...command.parameters, ...extraArgs],
          status: command.status,
          timestamp: command.timestamp,
          sha256: command.sha256,
        ),
        config.privilegeEscalation ?? NoPrivilegeEscalation(),
        workingDirectory: commandWorkingDirectory,
        runInShell: runInShell,
        onOutput: onOutput,
        executionService: executionService,
      );
    } finally {
      if (executionService is SSHExecutionService) {
        await executionService.disconnect();
      }
    }
  }

  Future<ExecutionService> _executionServiceForCommand() async {
    final connectionConfig = config.connectionConfig;
    if (connectionConfig == null) {
      return const LocalExecutionService();
    }

    final ssh = SSHExecutionService();
    await ssh.connect(connectionConfig.toMap());
    return ssh;
  }

  /// Write a config to the config file through the format service.
  Future<void> writeConfig(i3.Config config) =>
      formatService.writeConfig(config, configSink);

  /// Serialize a config to formatted text.
  String serializeConfig(i3.Config config) => formatService.serialize(config);
}

class _ConfigrIncludeFileSystem implements i3.FileSystem {
  final String configDir;

  const _ConfigrIncludeFileSystem(this.configDir);

  @override
  Future<String?> readFile(String path) {
    final resolved = p.isAbsolute(path)
        ? path
        : p.normalize(p.join(configDir, path));
    return const i3.PhysicalFileSystem().readFile(resolved);
  }
}
