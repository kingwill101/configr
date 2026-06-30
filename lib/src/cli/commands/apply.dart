import 'dart:async';
import 'dart:io' as dart_io;

import 'package:configr/src/cli/cli_exit_exception.dart';
import 'package:configr/src/watch/config_watcher.dart';
import 'base_command.dart';

class ApplyCommand extends BaseCommand {
  ApplyCommand() {
    argParser.addFlag(
      'force',
      abbr: 'f',
      help: 'Force apply all resources regardless of state',
    );
    argParser.addFlag(
      'watch',
      abbr: 'w',
      help: 'Watch for file changes and re-apply automatically',
      defaultsTo: false,
    );
    argParser.addFlag(
      'dry-run',
      help:
          'Show what would be done without making any changes (safe preview mode)',
      defaultsTo: false,
    );
    argParser.addFlag(
      'fail-fast',
      help: 'Stop at the first block error instead of continuing',
      defaultsTo: false,
    );
    argParser.addMultiOption(
      'target',
      help: 'Target specific host(s) by name (can be specified multiple times)',
    );
    argParser.addMultiOption(
      'target-role',
      help:
          'Target all hosts in the given role(s) (can be specified multiple times)',
    );
    argParser.addMultiOption(
      'target-group',
      help:
          'Target all hosts in the given group(s) (can be specified multiple times)',
    );
    argParser.addOption(
      'strategy',
      help: 'Execution strategy: linear, parallel, or serial',
      defaultsTo: 'linear',
      allowed: ['linear', 'parallel', 'serial'],
    );
    argParser.addMultiOption(
      'var',
      help:
          'Set a variable (key=value). Can be specified multiple times. '
          'Takes highest precedence over config and inventory variables.',
      valueHelp: 'key=value',
    );
  }

  @override
  String get name => 'apply';

  @override
  String get description => 'Apply configuration changes';

  @override
  Future<void> executeCommand() async {
    final force = argResults?['force'] as bool? ?? false;
    final watch = argResults?['watch'] as bool? ?? false;

    if (watch) {
      await _executeWatch();
    } else {
      await _executeV2(force: force);
    }
  }

  Future<void> _executeV2({bool force = false}) async {
    io.title('Apply Configuration (v2)');

    final dryRun = argResults?['dry-run'] as bool? ?? false;
    final failFast = argResults?['fail-fast'] as bool? ?? false;
    final interactive = configrConfig.interactiveMode;
    final verbose = configrConfig.verboseMode;
    final debug = configrConfig.debugMode;
    final hosts = argResults?['target'] as List<String>?;
    final roles = argResults?['target-role'] as List<String>?;
    final groups = argResults?['target-group'] as List<String>?;
    final strategy = argResults?['strategy'] as String? ?? 'linear';
    final rawVars = argResults?['var'] as List<String>?;
    final extraVars = rawVars != null
        ? {for (final pair in rawVars) ..._parseVarPair(pair)}
        : null;

    if (dryRun) {
      io.info('  [DRY-RUN] Preview mode — no changes will be made.');
    }
    if (failFast) {
      io.info('  [FAIL-FAST] Will stop at the first block error.');
    }

    try {
      await runtime.apply(
        force: force,
        dryRun: dryRun,
        failFast: failFast,
        interactive: interactive,
        verbose: verbose,
        debug: debug,
        hosts: hosts,
        roles: roles,
        groups: groups,
        strategy: strategy,
        extraVars: extraVars,
      );
      io.success('Configuration applied successfully.');
      io.line('');
      if (dryRun) {
        io.info(
          '[DRY-RUN] Would write lockfile to '
          '${runtime.resolvedConfigPath}.lock.json',
        );
      } else {
        io.info(
          'Lockfile written to '
          '${runtime.resolvedConfigPath}.lock.json',
        );
      }
    } catch (e) {
      io.error('Apply failed: $e');
      throw CliExitException(1);
    }
  }

  Future<void> _executeWatch() async {
    io.title('Apply with Watch (v2)');

    final watcher = ConfigWatcher(
      runtime: runtime,
      onStatus: (msg) => io.info(msg),
      onError: (msg) => io.error(msg),
    );

    late final StreamSubscription<dart_io.ProcessSignal> sigintSub;
    sigintSub = dart_io.ProcessSignal.sigint.watch().listen((_) {
      io.warn('\nShutting down watcher...');
      sigintSub.cancel();
      watcher.stop().then((_) => io.success('Watcher stopped.'));
    });

    try {
      // Apply once first.
      io.info('Applying configuration...');
      await runtime.apply();
      io.success('Initial apply complete.');

      await watcher.start();
      io.info('Watching for changes. Press Ctrl+C to stop.');
      await Completer<void>().future;
    } catch (e) {
      io.error('Watch apply error: $e');
    } finally {
      await sigintSub.cancel();
      await watcher.stop();
    }
  }

  /// Parse a `key=value` string from `--var`.
  /// Returns an empty map if the pair is malformed.
  Map<String, String> _parseVarPair(String pair) {
    final eq = pair.indexOf('=');
    if (eq <= 0) return {};
    return {pair.substring(0, eq): pair.substring(eq + 1)};
  }
}
