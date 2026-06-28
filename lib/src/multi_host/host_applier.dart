import 'package:configr/src/multi_host/connection_pool.dart' show ConnectionPool;
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
/// 3. Run `configr apply --remote` on the host
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

    final applyArgs = <String>['apply', remoteConfigPath];
    if (dryRun) applyArgs.add('--dry-run');
    if (failFast) applyArgs.add('--fail-fast');
    if (extraApplyArgs != null) applyArgs.addAll(extraApplyArgs);

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
