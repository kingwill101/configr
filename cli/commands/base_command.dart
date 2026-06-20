import 'package:args/command_runner.dart';
import 'package:configr/src/config_manager.dart';

/// Base command class that integrates with CommandRunner and provides access to ConfigManager
abstract class BaseCommand extends Command<void> {
  ConfigManager? _configManager;

  ConfigManager get configManager => _configManager!;
  
  set configManager(ConfigManager value) {
    _configManager = value;
  }

  @override
  void run() {
    if (_configManager == null) {
      throw StateError('ConfigManager not set. Call setConfigManager() first.');
    }
    
    // Common validation and setup logic
    try {
      executeCommand();
    } catch (e) {
      // Common error handling
      rethrow;
    }
  }

  /// Override this method in subcommands to implement specific command logic
  void executeCommand();
}
