import 'package:configr/commands/command.dart';

class ApplyCommand extends Command {
  ApplyCommand(super.configManager);

  @override
  Future<void> execute() async {
    print("applying config ${configManager.localPath}");
    await configManager.load();
    await configManager.applyConfig();
    print('Configuration applied successfully.');
  }
}
