import 'package:configr/config_manager.dart';

abstract class Command {
  final ConfigManager configManager;

  Command(this.configManager);

  Future<void> execute();
}
