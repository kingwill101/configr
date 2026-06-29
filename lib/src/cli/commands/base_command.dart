import 'package:artisanal/args.dart';
import 'package:configr/src/configr_config.dart';
import 'package:configr/src/configr_runtime.dart';

/// Base command class for Configr CLI commands.
///
/// Provides access to [ConfigrRuntime] and [ConfigrConfig].
/// Set via [ConfigrCommandRunner.run] before command execution.
abstract class BaseCommand extends Command<void> {
  ConfigrRuntime? _runtime;

  /// The runtime for executing configuration operations.
  ConfigrRuntime get runtime => _runtime!;

  set runtime(ConfigrRuntime value) {
    _runtime = value;
  }

  /// The config object from [runtime].
  ConfigrConfig get configrConfig => runtime.config;

  @override
  Future<void> run() async {
    if (_runtime == null) {
      throw StateError('ConfigrRuntime not set. Call setRuntime() first.');
    }

    try {
      await executeCommand();
    } catch (e) {
      rethrow;
    }
  }

  /// Override this in subcommands to implement specific command logic.
  Future<void> executeCommand();
}
