
import 'base_command.dart';

class ApplyCommand extends BaseCommand {
  ApplyCommand() {
    argParser.addFlag('force', abbr: 'f', help: 'Force apply all resources regardless of state');
  }

  @override
  String get name => 'apply';
  
  @override
  String get description => 'Apply configuration changes';

  @override
  void executeCommand() async {
    final force = argResults?['force'] as bool? ?? false;
    await configManager.load();
    configManager.options = configManager.options.copyWith(force: force);
    await configManager.applyConfig();
  }
}
