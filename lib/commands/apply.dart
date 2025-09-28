
import 'package:configr/commands/command.dart';

class ApplyCommand extends Command {
  final bool force;

  ApplyCommand(super.configManager, {this.force = false});

  @override
  Future<void> execute() async {
    await configManager.load();
    configManager.options = configManager.options.copyWith(force: force);
    await configManager.applyConfig();
  }
}
