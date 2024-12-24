import 'package:configr/commands/command.dart';

class FormatCommand extends Command {
  FormatCommand(super.configManager);

  @override
  Future<void> execute() async {
    await configManager.load();
    configManager.saveConfig();
    print('formatted successfully');
  }
}
