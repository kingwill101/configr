/// Configuration options for the Configr runtime.
///
/// Controls behavior like fail-fast mode, interactive prompts, and dry-run.
class ConfigOptions {
  final bool failFast;
  final bool interactive;
  final bool dryRun;
  final bool force;

  const ConfigOptions({
    this.failFast = true,
    this.interactive = true,
    this.dryRun = false,
    this.force = false,
  });

  ConfigOptions copyWith({
    bool? failFast,
    bool? interactive,
    bool? dryRun,
    bool? force,
  }) {
    return ConfigOptions(
      failFast: failFast ?? this.failFast,
      interactive: interactive ?? this.interactive,
      dryRun: dryRun ?? this.dryRun,
      force: force ?? this.force,
    );
  }
}
