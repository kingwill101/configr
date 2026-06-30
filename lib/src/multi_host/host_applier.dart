import 'package:configr/src/multi_host/connection_pool.dart'
    show ConnectionPool;
import 'package:configr/src/blocks/v2_apply.dart' show applyV2;
import 'package:configr/src/multi_host/host.dart' show Host;
import 'package:configr/src/multi_host/host_execution_context.dart'
    show HostExecutionContext;
import 'package:configr/src/plugins/configr_plugin.dart'
    show ConfigrPluginLoader;
import 'package:configr/src/utils/event_bus.dart' show EventBus;
import 'package:configr/src/utils/logging.dart' show logger;

/// Apply configuration on a single host via SSH from the local process.
///
/// Flow:
/// 1. Acquire an SSH connection from [pool] for [host]
/// 2. Run the local v2 pipeline with the host's SSH-backed filesystem and
///    process backend
/// 3. Pass host vars as CLI-precedence vars for this host
/// 4. Return a [HostExecutionContext] with success/failure status
Future<HostExecutionContext> applyOnHost({
  required Host host,
  required ConnectionPool pool,
  required String configPath,
  String remoteConfigPath = '/tmp/configr_config',
  required EventBus eventBus,
  required bool dryRun,
  required bool failFast,
  ConfigrPluginLoader? pluginLoader,

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

    final hostVars = <String, String>{};
    if (extraVars != null) {
      hostVars.addAll(extraVars);
    }
    // Host vars take precedence over group/extra vars.
    hostVars.addAll(host.variables);

    final hostLogger = logger.withContext({'host': host.name});
    hostLogger.info('Running local apply through SSH backends');
    await applyV2(
      configPath,
      eventBus: eventBus,
      dryRun: dryRun,
      failFast: failFast,
      runtimeFileSystem: ssh.fileSystem,
      runtimeExecutionService: ssh,
      runtimeProcessBackend: ssh.processBackend,
      pluginLoader: pluginLoader,
      extraVars: hostVars.isNotEmpty ? hostVars : null,
      appliedBlocksCollector: context.appliedBlocks,
      writeLockfile: false,
      runMultiHost: false,
    );

    hostLogger.info('Apply completed successfully');
    context.succeeded = true;
    // Keep the pool-owned SSH connection alive until the caller releases it.
    // The local apply opens its own short-lived SSH service for the DI-backed
    // filesystem/process abstractions.
    if (!ssh.isConnected) {
      hostLogger.warning('SSH pool connection closed unexpectedly');
    }
  } catch (e) {
    context.succeeded = false;
    context.errorMessage = '$e';
    logger
        .withContext({'host': host.name, 'error': '$e'})
        .error('Connection/execution failed');
  }

  return context;
}
