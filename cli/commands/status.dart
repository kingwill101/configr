import 'base_command.dart';

class StatusCommand extends BaseCommand {

  @override
  String get name => 'status';
  
  @override
  String get description => 'Show configuration status';

  @override
  void executeCommand() async {
    await configManager.load();
    // Implement status logic here
    print('Status functionality not yet implemented.');
  }
}
