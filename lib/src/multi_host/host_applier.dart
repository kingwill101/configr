import 'package:configr/src/multi_host/connection_pool.dart'
    show ConnectionPool;
import 'package:configr/src/multi_host/host.dart' show Host;
import 'package:configr/src/multi_host/host_execution_context.dart'
    show HostExecutionContext;
import 'package:configr/src/utils/event_bus.dart' show EventBus;
import 'package:configr/src/utils/logging.dart' show logger;

/// Apply configuration on a single host via SSH.
///
/// Flow:
/// 1. Acquire an SSH connection from [pool] for [host]
/// 2. Upload the local config file to [remoteConfigPath] on the host
/// 3. Run `configr apply --remote` on the host with host vars as `--var` flags
///    to populate the variable precedence middleware on the remote end
/// 4. Return a [HostExecutionContext] with success/failure status
///
/// The remote configr binary must be available on the target host.
Future<HostExecutionContext> applyOnHost({
  required Host host,
  required ConnectionPool pool,
  required String configPath,
  String remoteConfigPath = '/tmp/configr_config',
  required EventBus eventBus,
  required bool dryRun,
  required bool failFast,
  List<String>? extraApplyArgs,

  /// Additional variables to pass as `--var` flags, e.g. group vars merged
  /// from inventory. These are layered above host.variables.
  Map<String, String>? extraVars,
}) async {
  final context = HostExecutionContext(
    host: host,
    remoteConfigPath: remoteConfigPath,
    eventBus: eventBus,
    dryRun: dryRun,
    failFast: failFast,
  );

  try {
    final ssh = await pool.acquire(host);

    logger.info('[${host.name}] Uploading config to $remoteConfigPath');
    await ssh.putFile(configPath, remoteConfigPath);

    final applyArgs = <String>[
      '--config',
      remoteConfigPath,
      '--v2',
      '--no-interaction',
      'apply',
    ];
    if (dryRun) applyArgs.add('--dry-run');
    if (failFast) applyArgs.add('--fail-fast');
    if (extraApplyArgs != null) applyArgs.addAll(extraApplyArgs);

    // Pass host variables as --var flags so the remote configr picks them up
    // in the CLI vars precedence layer (highest priority).
    for (final entry in host.variables.entries) {
      applyArgs.add('--var');
      applyArgs.add('${entry.key}=${entry.value}');
    }

    // Also pass extra vars (e.g. group vars from inventory).
    if (extraVars != null) {
      for (final entry in extraVars.entries) {
        // Host vars take precedence over extra vars — skip if already set.
        if (host.variables.containsKey(entry.key)) continue;
        applyArgs.add('--var');
        applyArgs.add('${entry.key}=${entry.value}');
      }
    }

    logger.info('[${host.name}] Running: configr ${applyArgs.join(' ')}');
    final result = await ssh.run('configr', applyArgs);

    if (result.exitCode == 0) {
      logger.info('[${host.name}] Apply completed successfully');
      context.succeeded = true;
    } else {
      final stderr = (result.stderr as String?)?.trim() ?? '';
      context.succeeded = false;
      context.errorMessage =
          'configr apply exited with code ${result.exitCode}: $stderr';
      logger.error('[${host.name}] ${context.errorMessage}');
    }
  } catch (e) {
    context.succeeded = false;
    context.errorMessage = '$e';
    logger.error('[${host.name}] Connection/execution failed: $e');
  }

  return context;
}
