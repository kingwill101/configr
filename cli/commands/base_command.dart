import 'package:artisanal/args.dart';
import 'package:configr/src/config_manager.dart';
import 'package:configr/src/configr_config.dart';
import 'package:configr/src/configr_runtime.dart';

/// Base command class for Configr CLI commands.
///
/// Provides access to both [ConfigrRuntime] (v2 pipeline) and
/// [ConfigManager] (v1 legacy) so commands can implement both paths.
/// New code should prefer [runtime] over [configManager].
abstract class BaseCommand extends Command<void> {
  ConfigManager? _configManager;

  /// Legacy v1 ConfigManager accessor.
  ///
  /// Set by [ConfigrCommandRunner.run] before command execution.
  /// New code should use [runtime] instead.
  ConfigManager get configManager => _configManager!;

  set configManager(ConfigManager value) {
    _configManager = value;
  }

  /// The v2 runtime, lazily created from [configManager]'s config.
  ConfigrRuntime get runtime => ConfigrRuntime(configManager.configrConfig);

  /// The config object from [configManager].
  ConfigrConfig get configrConfig => configManager.configrConfig;

  @override
  void run() {
    if (_configManager == null) {
      throw StateError('ConfigManager not set. Call setConfigManager() first.');
    }

    try {
      executeCommand();
    } catch (e) {
      rethrow;
    }
  }

  /// Override this in subcommands to implement specific command logic.
  void executeCommand();
}
