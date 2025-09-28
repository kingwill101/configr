import 'package:configr/commands/command.dart';
import 'package:configr/utils/logging.dart';

class RollbackCommand extends Command {
  final int? count;

  RollbackCommand(super.configManager, {this.count});

  @override
  Future<void> execute() async {
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
  }
}
