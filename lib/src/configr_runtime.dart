import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/blocks/v2_apply.dart';
import 'package:configr/src/configr_config.dart';
import 'package:configr/src/format/config_source.dart';
import 'package:configr/src/format/format_service.dart';
import 'package:configr/src/utils/event_bus.dart';
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
  }) => applyV2(
    resolvedConfigPath,
    eventBus: eventBus,
    force: force,
    dryRun: dryRun,
    failFast: failFast,
    interactive: interactive,
    verbose: verbose,
    debug: debug,
    privilegeEscalation: config.privilegeEscalation,
    pluginLoader: config.pluginLoader,
  );

  /// Rollback applied blocks.
  Future<void> rollback({int? count, bool dryRun = false}) => rollbackV2(
    resolvedConfigPath,
    eventBus: eventBus,
    count: count,
    dryRun: dryRun,
    pluginLoader: config.pluginLoader,
  );

  /// Parse and collect block snapshots without executing them.
  Future<List<BlockSnapshot>> parseAndCollect() => parseAndCollectBlocks(
    resolvedConfigPath,
    eventBus: eventBus,
    pluginLoader: config.pluginLoader,
  );

  /// Read and parse the config file through the format service.
  Future<i3.Config> readConfig() => formatService.readConfig(configSource);

  /// Write a config to the config file through the format service.
  Future<void> writeConfig(i3.Config config) =>
      formatService.writeConfig(config, configSink);

  /// Serialize a config to formatted text.
  String serializeConfig(i3.Config config) => formatService.serialize(config);
}
