import 'package:configr/commands/base_command.dart';
import 'package:configr/utils/logging.dart';

class RollbackCommand extends BaseCommand {
  RollbackCommand() {
    argParser.addOption('count', abbr: 'n', help: 'Number of most recent resources to rollback', valueHelp: 'number');
  }

  @override
  String get name => 'rollback';
  
  @override
  String get description => 'Rollback configuration changes';

  @override
  void executeCommand() async {
    final count = argResults?['count'] != null ? int.tryParse(argResults!['count']) : null;
    
    try {
      await configManager.load();
      logger.info('Starting rollback of configuration...');
      if (count != null && count! < 1) {
        logger.severe('Invalid rollback count: $count');
        return;
      }
      if (count != null) {
        logger.info('Rolling back last $count operations');
      }

      await configManager.rollbackConfig(count: count);
      logger.info('Configuration rollback completed successfully');
    } catch (e) {
      // Handle specific error cases with user-friendly messages
      if (e.toString().contains('Configuration file not found')) {
        logger.severe('Configuration file not found.\n\nPlease run this command from a directory containing a config file, or specify a config file path.');
        return;
      } else if (e.toString().contains('No rollback information available')) {
        logger.info('Nothing to rollback. No previous configuration has been applied.');
        return;
      }
      logger.severe('Rollback failed: $e');
    }
  }
}
