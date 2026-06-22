import 'package:configr/src/format/format_service.dart';
import 'package:configr/src/models/config_options.dart';
import 'package:configr/src/plugins/configr_plugin.dart';
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
  final bool useV2;
  final List<String> pluginDirs;
  final ConfigrPluginLoader? pluginLoader;
  final FormatService formatService;

  // Phase K: Privilege escalation persistence
  final Duration privilegeLockTimeout;
  final bool privilegeLockEnabled;
  final PrivilegeLock? privilegeLock;

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
    this.useV2 = false,
    this.pluginDirs = const [],
    this.privilegeLockTimeout = const Duration(minutes: 15),
    this.privilegeLockEnabled = false,
    ConfigrPluginLoader? pluginLoader,
    PrivilegeLock? privilegeLock,
    FormatService? formatService,
  }) : fileSystem = fileSystem ?? const LocalFileSystem(),
       options = options ?? ConfigOptions(),
       eventBus = eventBus ?? EventBus(),
       pluginLoader =
           pluginLoader ?? ConfigrPluginLoader(pluginDirectories: pluginDirs),
       privilegeLock =
           privilegeLock ??
           (keepPrivilegeLock
               ? PrivilegeLock(timeout: privilegeLockTimeout)
               : null),
       formatService = formatService ?? FormatService();

  /// Whether a privilege lock is currently active.
  bool get hasActivePrivilegeLock =>
      privilegeLock != null && privilegeLock!.isActive;
}
