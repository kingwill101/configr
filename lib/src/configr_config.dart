import 'package:configr/src/models/config.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:configr/src/utils/privilege_escalation.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';

/// Configuration options for Configr.
///
/// This class holds all configuration needed for ConfigManager operation,
/// including filesystem, event bus, UI handler, and privilege escalation.
class ConfigrConfig {
  final FileSystem fileSystem;
  final ConfigOptions options;
  final PrivilegeEscalation? privilegeEscalation;
  final EventBus eventBus;
  final dynamic uiHandler;
  final String? configPath;
  final bool keepPrivilegeLock;
  final String? repoUrl;
  final String? localPath;
  final bool verboseMode;
  final bool debugMode;
  final bool dryRunMode;
  final bool interactiveMode;

  ConfigrConfig({
    FileSystem? fileSystem,
    ConfigOptions? options,
    this.privilegeEscalation,
    EventBus? eventBus,
    this.uiHandler,
    this.configPath,
    this.keepPrivilegeLock = false,
    this.repoUrl,
    this.localPath,
    this.verboseMode = false,
    this.debugMode = false,
    this.dryRunMode = false,
    this.interactiveMode = false,
  }) : fileSystem = fileSystem ?? const LocalFileSystem(),
        options = options ?? ConfigOptions(),
        eventBus = eventBus ?? EventBus();
}
