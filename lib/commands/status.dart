import 'package:configr/commands/command.dart';

class StatusCommand extends Command {
  StatusCommand(super.configManager);

  @override
  Future<void> execute() async {
    await configManager.load();
    // Implement status logic here
    print('Status functionality not yet implemented.');
  }
}
