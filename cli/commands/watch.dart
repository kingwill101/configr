import 'dart:async';
import 'dart:io' as dart_io;

import 'package:configr/src/watch/config_watcher.dart';
import 'base_command.dart';

class WatchCommand extends BaseCommand {
  WatchCommand() {
    argParser.addFlag(
      'once',
      help: 'Apply once and exit instead of watching continuously',
      defaultsTo: false,
    );
  }

  @override
  String get name => 'watch';

  @override
  String get description =>
      'Watch configuration files and apply changes automatically';

  @override
  void executeCommand() async {
    final once = argResults?['once'] as bool? ?? false;

    io.title('Configuration Watch');

    final watcher = ConfigWatcher(
      runtime: runtime,
      onStatus: (msg) => io.info(msg),
      onError: (msg) => io.error(msg),
    );

    // Register a SIGINT handler to stop watching gracefully.
    late final StreamSubscription<dart_io.ProcessSignal> sigintSub;
    sigintSub = dart_io.ProcessSignal.sigint.watch().listen((_) {
      io.warn('\nShutting down watcher...');
      sigintSub.cancel();
      watcher.stop().then((_) => io.success('Watcher stopped.'));
    });

    try {
      await watcher.start();

      if (once) {
        io.info('Applying configuration...');
        await runtime.apply();
        io.success('Apply complete.');
        await watcher.stop();
        await sigintSub.cancel();
      } else {
        io.info('Watching for changes. Press Ctrl+C to stop.');
        // Keep the process alive until interrupted.
        await Completer<void>().future;
      }
    } catch (e) {
      io.error('Watch error: $e');
    } finally {
      await sigintSub.cancel();
      await watcher.stop();
    }
  }
}
