import 'base_command.dart';

class FormatCommand extends BaseCommand {

  @override
  String get name => 'format';
  
  @override
  String get description => 'Format configuration file';

  @override
  void executeCommand() async {
    await configManager.load();
    configManager.saveConfig();
    print('formatted successfully');
  }
}
