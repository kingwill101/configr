import 'dart:async';
import 'dart:io' as dart_io;

import 'package:configr/src/events/module_events.dart';
import 'base_command.dart';
import 'package:configr/src/utils/logging.dart';

class RollbackCommand extends BaseCommand {
  RollbackCommand() {
    argParser.addOption(
      'count',
      abbr: 'n',
      help: 'Number of most recent resources to rollback',
      valueHelp: 'number',
    );
  }

  @override
  String get name => 'rollback';

  @override
  String get description => 'Rollback configuration changes';

  @override
  Future<void> executeCommand() async {
    final count = argResults?['count'] != null
        ? int.tryParse(argResults!['count'])
        : null;
    await _executeV2(count: count);
  }

  Future<void> _executeV2({int? count}) async {
    io.title('Rollback Configuration (v2)');

    final interactive = configrConfig.interactiveMode;

    // Interactive mode — prompt user for confirmation
    if (interactive) {
      dart_io.stdout.write(
        'Rollback from ${runtime.resolvedConfigPath.split('/').last}? [Y/n] ',
      );
      final response = (dart_io.stdin.readLineSync() ?? 'y')
          .trim()
          .toLowerCase();
      if (response != 'y' && response != 'yes' && response != '') {
        io.info('Rollback cancelled by user.');
        return;
      }
    }

    // Subscribe to block-level rollback events for live progress.
    final subscriptions = <StreamSubscription>[];
    subscriptions.add(
      runtime.eventBus.stream.listen((event) {
        switch (event) {
          case StartedEvent(:final message, :final moduleId):
            io.line('  ◀ $moduleId: $message');
          case CompletedEvent(:final message, :final moduleId):
            io.success('  ✔ $moduleId: $message');
          case FailedEvent(:final message, :final moduleId):
            io.error('  ✘ $moduleId: $message');
          default:
            break;
        }
      }),
    );

    try {
      await runtime.rollback(count: count);
      io.success('Rollback completed successfully.');
    } catch (e) {
      if (e.toString().contains('Configuration file not found')) {
        io.error(
          'Configuration file not found.\n\n'
          'Please run this command from a directory containing a config file, '
          'or specify a config file path.',
        );
      } else if (e.toString().contains('No rollback information available')) {
        io.info(
          'Nothing to rollback. No previous configuration has been applied.',
        );
      } else {
        io.error('Rollback failed: $e');
        logger.error('Rollback error: $e');
      }
    } finally {
      for (final sub in subscriptions) {
        await sub.cancel();
      }
    }
  }
}
