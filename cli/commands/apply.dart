import 'dart:async';
import 'dart:io' as dart_io;

import 'package:configr/src/events/module_events.dart';
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
  }

  @override
  String get name => 'apply';

  @override
  String get description => 'Apply configuration changes';

  @override
  void executeCommand() async {
    final force = argResults?['force'] as bool? ?? false;
    final watch = argResults?['watch'] as bool? ?? false;
    final useV2 = configrConfig.useV2;

    if (useV2 && watch) {
      await _executeWatch();
    } else if (useV2) {
      await _executeV2(force: force);
    } else {
      await _executeV1(force: force);
    }
  }

  Future<void> _executeV2({bool force = false}) async {
    io.title('Apply Configuration (v2)');

    final dryRun = argResults?['dry-run'] as bool? ?? false;
    final failFast = argResults?['fail-fast'] as bool? ?? false;
    final interactive = configrConfig.interactiveMode;
    final verbose = configrConfig.verboseMode;
    final debug = configrConfig.debugMode;

    if (dryRun) {
      io.info('  [DRY-RUN] Preview mode — no changes will be made.');
    }
    if (failFast) {
      io.info('  [FAIL-FAST] Will stop at the first block error.');
    }

    // Subscribe to block-level events for live progress output.
    final subscriptions = <StreamSubscription>[];
    subscriptions.add(
      runtime.eventBus.stream.listen((event) {
        switch (event) {
          case StartedEvent(:final message, :final moduleId):
            io.line('  ▶ $moduleId: $message');
          case CompletedEvent(:final message, :final moduleId):
            io.success('  ✔ $moduleId: $message');
          case FailedEvent(:final message, :final moduleId):
            io.error('  ✘ $moduleId: $message');
          case StatusUpdateEvent(:final message, :final moduleId):
            io.info('  ℹ $moduleId: $message');
          default:
            break;
        }
      }),
    );

    try {
      await runtime.apply(
        force: force,
        dryRun: dryRun,
        failFast: failFast,
        interactive: interactive,
        verbose: verbose,
        debug: debug,
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
      dart_io.exit(1);
    } finally {
      for (final sub in subscriptions) {
        await sub.cancel();
      }
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

  Future<void> _executeV1({required bool force}) async {
    await configManager.load();
    configManager.options = configManager.options.copyWith(force: force);
    await configManager.applyConfig();
  }
}
