import 'package:configr/commands/command.dart';

class DiffCommand extends Command {
  DiffCommand(super.configManager);

  @override
  Future<void> execute() async {
    print("diffing config ${configManager.localPath}");
  }
}
