import 'base_command.dart';

class DiffCommand extends BaseCommand {

  @override
  String get name => 'diff';
  
  @override
  String get description => 'Show configuration differences';

  @override
  void executeCommand() async {
    print("diffing config ${configManager.localPath}");
  }
}
