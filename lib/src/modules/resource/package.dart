import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/modules/resource/resource_module.dart';
import 'package:configr/src/package_management/package_management_factory.dart';
import 'package:configr/src/package_management/package_manger.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:configr/src/utils/privilege_escalation.dart';

/// Package module for multi-platform package management
class FilePackageModule extends ResourceModule {
  // State getters
  String get packageManager => state['packageManager'] as String? ?? 'auto';
  List<String> get packages => (state['packages'] as List<dynamic>?)?.cast<String>() ?? [];
  Map<String, String> get packageVersions {
    final versions = state['packageVersions'];
    if (versions == null) return {};
    if (versions is Map<String, String>) return versions;
    if (versions is Map<String, dynamic>) {
      return versions.map((key, value) => MapEntry(key, value.toString()));
    }
    if (versions is Map<dynamic, dynamic>) {
      return versions.map((key, value) => MapEntry(key.toString(), value.toString()));
    }
    return {};
  }
  List<String> get repositories => (state['repositories'] as List<dynamic>?)?.cast<String>() ?? [];
  String get operation => state['operation'] as String? ?? 'install';
  bool get force => state['force'] as bool? ?? false;
  bool get updateCache => state['updateCache'] as bool? ?? true;
  bool get skipIfInstalled => state['skipIfInstalled'] as bool? ?? true;
  bool get installGlobally => state['installGlobally'] as bool? ?? true;
  int get packageId => state['packageId'] as int? ?? 0;
  Map<String, String> get operationResults {
    final results = state['operationResults'];
    if (results == null) return {};
    if (results is Map<String, String>) return results;
    if (results is Map<String, dynamic>) {
      return results.map((key, value) => MapEntry(key, value.toString()));
    }
    if (results is Map<dynamic, dynamic>) {
      return results.map((key, value) => MapEntry(key.toString(), value.toString()));
    }
    return {};
  }
  int get packagesProcessed => state['packagesProcessed'] as int? ?? 0;
  int get packagesSkipped => state['packagesSkipped'] as int? ?? 0;
  int get errorsEncountered => state['errorsEncountered'] as int? ?? 0;

  FilePackageModule(super.file, super.action,
      {super.allowedActions = const ['package'], super.fileSystem, super.eventBus}) {
    // Set default values first
    updateState({
      'packageManager': 'auto',
      'packages': [],
      'packageVersions': {},
      'repositories': [],
      'operation': 'install',
      'force': false,
      'updateCache': true,
      'skipIfInstalled': true,
      'installGlobally': true,
      'packageId': 0,
      'operationResults': {},
      'packagesProcessed': 0,
      'packagesSkipped': 0,
      'errorsEncountered': 0,
    });
    
    // Load configuration from action properties
    _loadConfiguration();
    
    // Restore state from action after configuration loading (for rollback)
    if (action.state.isNotEmpty) {
      updateState(action.state);
    }
  }

  void _loadConfiguration() {
    final props = action.properties;
    
    updateState({
      'packageManager': props['package_manager'] ?? packageManager,
      'operation': props['operation'] ?? operation,
      'force': props['force'] ?? force,
      'updateCache': props['update_cache'] ?? updateCache,
      'skipIfInstalled': props['skip_if_installed'] ?? skipIfInstalled,
      'installGlobally': props['install_globally'] ?? installGlobally,
    });

    if (props.containsKey('packages')) {
      final packagesValue = props['packages'];
      if (packagesValue is List<dynamic>) {
        updateState({'packages': packagesValue.cast<String>()});
      } else if (packagesValue is String) {
        // Handle list syntax as string (e.g., '["package1", "package2"]')
        if (packagesValue.startsWith('[') && packagesValue.endsWith(']')) {
          // Parse the list syntax manually
          final listContent = packagesValue.substring(1, packagesValue.length - 1);
          final packages = listContent
              .split(',')
              .map((p) => p.trim().replaceAll('"', '').replaceAll("'", ''))
              .where((p) => p.isNotEmpty)
              .toList();
          updateState({'packages': packages});
        } else {
          // Handle single package as string
          updateState({'packages': [packagesValue]});
        }
      }
    }

    if (props.containsKey('package_versions')) {
      final versions = props['package_versions'] as Map<String, dynamic>?;
      if (versions != null) {
        updateState({'packageVersions': versions.cast<String, String>()});
      }
    }

    if (props.containsKey('repositories')) {
      final repoValue = props['repositories'];
      if (repoValue is List<dynamic>) {
        updateState({'repositories': repoValue.cast<String>()});
      } else if (repoValue is String) {
        // Handle list syntax as string (e.g., '["repo1", "repo2"]')
        if (repoValue.startsWith('[') && repoValue.endsWith(']')) {
          // Parse the list syntax manually
          final listContent = repoValue.substring(1, repoValue.length - 1);
          final repos = listContent
              .split(',')
              .map((r) => r.trim().replaceAll('"', '').replaceAll("'", ''))
              .where((r) => r.isNotEmpty)
              .toList();
          updateState({'repositories': repos});
        } else {
          // Handle single repository as string
          updateState({'repositories': [repoValue]});
        }
      }
    }
  }

  @override
  Future<void> execute() async {
    emitEvent(StartedEvent(moduleId: action.id, message: 'Starting package management operation'));

    try {
      final packageId = DateTime.now().millisecondsSinceEpoch;
      updateState({'packageId': packageId});

      if (packages.isEmpty) {
        throw ActionFailedException('No packages specified for package operation');
      }

      // Get package manager (auto-detect or specified)
      final manager = await _getPackageManager();
      logger.info('Using package manager: ${manager.name}');

      // Update cache if requested
      if (updateCache) {
        await _updatePackageCache(manager);
      }

      // Add repositories if specified
      if (repositories.isNotEmpty) {
        await _addRepositories(manager);
      }

      // Perform package operations
      await _performPackageOperations(manager);

      logger.info('Package operation completed successfully. Packages processed: $packagesProcessed, Skipped: $packagesSkipped');
      emitEvent(CompletedEvent(moduleId: action.id, message: 'Package management operation completed successfully'));
      
      // Save state after successful execution
      await saveState();
    } catch (e) {
      updateState({'errorsEncountered': errorsEncountered + 1});
      emitEvent(FailedEvent(moduleId: action.id, message: 'Package operation failed: $e'));
      rethrow;
    }
  }

  Future<PackageManager> _getPackageManager() async {
    if (packageManager != 'auto') {
      // Use specified package manager with appropriate privilege escalation
      final privilegeEscalation = _getPrivilegeEscalationForManager(packageManager);
      final manager = PackageManagerFactory.create(packageManager, privilegeEscalation);
      if (!await manager.isAvailable()) {
        throw ActionFailedException('Package manager $packageManager is not available on this system');
      }
      return manager;
    } else {
      // Auto-detect available package manager
      // Try system package managers first (need sudo)
      final systemManagers = ['apt', 'pacman', 'pamac', 'docker'];
      for (final managerName in systemManagers) {
        try {
          final privilegeEscalation = _getPrivilegeEscalationForManager(managerName);
          final manager = PackageManagerFactory.create(managerName, privilegeEscalation);
          if (await manager.isAvailable()) {
            return manager;
          }
        } catch (e) {
          // Continue to next manager
        }
      }
      
      // Try user package managers (no sudo needed)
      final userManagers = ['npm'];
      for (final managerName in userManagers) {
        try {
          final privilegeEscalation = _getPrivilegeEscalationForManager(managerName);
          final manager = PackageManagerFactory.create(managerName, privilegeEscalation);
          if (await manager.isAvailable()) {
            return manager;
          }
        } catch (e) {
          // Continue to next manager
        }
      }
      
      throw ActionFailedException('No supported package manager found on this system');
    }
  }

  PrivilegeEscalation _getPrivilegeEscalationForManager(String managerName) {
    // User package managers don't need sudo
    if (managerName == 'npm') {
      return NoPrivilegeEscalation();
    }
    
    // System package managers need sudo
    return InteractiveSudoEscalation();
  }

  Future<void> _updatePackageCache(PackageManager manager) async {
    try {
      logger.info('Updating package cache...');
      // This would need to be implemented per package manager
      // For now, we'll just log that we're updating
      emitEvent(ProgressEvent(moduleId: action.id, message: 'Updating package cache'));
    } catch (e) {
      logger.warning('Failed to update package cache: $e');
    }
  }

  Future<void> _addRepositories(PackageManager manager) async {
    try {
      logger.info('Adding repositories: $repositories');
      // This would need to be implemented per package manager
      // For now, we'll just log that we're adding repositories
      emitEvent(ProgressEvent(moduleId: action.id, message: 'Adding repositories: ${repositories.join(', ')}'));
    } catch (e) {
      logger.warning('Failed to add repositories: $e');
    }
  }

  Future<void> _performPackageOperations(PackageManager manager) async {
    for (final packageName in packages) {
      try {
        final version = packageVersions[packageName];
        
        switch (operation.toLowerCase()) {
          case 'install':
            await _installPackage(manager, packageName, version);
            break;
          case 'uninstall':
            await _uninstallPackage(manager, packageName);
            break;
          case 'upgrade':
            await _upgradePackage(manager, packageName, version);
            break;
          case 'reinstall':
            await _reinstallPackage(manager, packageName, version);
            break;
          default:
            throw ActionFailedException('Unsupported package operation: $operation');
        }
      } catch (e) {
        updateState({'errorsEncountered': errorsEncountered + 1});
        logger.severe('Failed to process package $packageName: $e');
        emitEvent(ProgressEvent(moduleId: action.id, message: 'Failed to process package: $packageName'));
      }
    }
  }

  Future<void> _installPackage(PackageManager manager, String packageName, String? version) async {
    // Check if already installed
    bool isAlreadyInstalled = false;
    if (manager is GlobalLocalContextCapability) {
      isAlreadyInstalled = installGlobally 
          ? await manager.isInstalledGlobally(packageName)
          : await manager.isInstalledLocally(packageName);
    } else {
      isAlreadyInstalled = await manager.isInstalled(packageName);
    }
    
    if (skipIfInstalled && isAlreadyInstalled) {
      logger.info('Package $packageName is already installed, skipping');
      updateState({'packagesSkipped': packagesSkipped + 1});
      return;
    }

    logger.info('Installing package: $packageName${version != null ? ' version $version' : ''}');
    emitEvent(ProgressEvent(moduleId: action.id, message: 'Installing package: $packageName'));

    // Use appropriate installation method based on configuration and capabilities
    if (installGlobally && manager is GlobalInstallCapability) {
      await manager.installGlobally(packageName, version: version);
    } else if (!installGlobally && manager is LocalInstallCapability) {
      await manager.installLocally(packageName, version: version);
    } else {
      // Fallback to default install method
      await manager.install(packageName, version: version);
    }
    
    // Get the actual installed version
    String? installedVersion;
    if (manager is GlobalLocalContextCapability) {
      installedVersion = installGlobally 
          ? await manager.getInstalledVersionGlobally(packageName)
          : await manager.getInstalledVersionLocally(packageName);
    } else {
      installedVersion = await manager.getInstalledVersion(packageName);
    }
    
    updateState({'packagesProcessed': packagesProcessed + 1});
    final results = Map<String, String>.from(operationResults);
    results[packageName] = 'installed:${installedVersion ?? 'unknown'}';
    updateState({'operationResults': results});
  }

  Future<void> _uninstallPackage(PackageManager manager, String packageName) async {
    // Check if installed
    if (!await manager.isInstalled(packageName)) {
      if (skipIfInstalled) {
        logger.info('Package $packageName is not installed, skipping');
        updateState({'packagesSkipped': packagesSkipped + 1});
        return;
      } else {
        throw ActionFailedException('Package $packageName is not installed');
      }
    }

    logger.info('Uninstalling package: $packageName');
    emitEvent(ProgressEvent(moduleId: action.id, message: 'Uninstalling package: $packageName'));

    await manager.uninstall(packageName);
    
    updateState({'packagesProcessed': packagesProcessed + 1});
    final results = Map<String, String>.from(operationResults);
    results[packageName] = 'uninstalled';
    updateState({'operationResults': results});
  }

  Future<void> _upgradePackage(PackageManager manager, String packageName, String? version) async {
    // Check if installed
    if (!await manager.isInstalled(packageName)) {
      if (skipIfInstalled) {
        logger.info('Package $packageName is not installed, skipping upgrade');
        updateState({'packagesSkipped': packagesSkipped + 1});
        return;
      } else {
        throw ActionFailedException('Package $packageName is not installed');
      }
    }

    logger.info('Upgrading package: $packageName${version != null ? ' to version $version' : ''}');
    emitEvent(ProgressEvent(moduleId: action.id, message: 'Upgrading package: $packageName'));

    // For upgrade, we reinstall with the new version
    // Use appropriate installation method based on configuration and capabilities
    if (installGlobally && manager is GlobalInstallCapability) {
      await manager.installGlobally(packageName, version: version);
    } else if (!installGlobally && manager is LocalInstallCapability) {
      await manager.installLocally(packageName, version: version);
    } else {
      // Fallback to default install method
      await manager.install(packageName, version: version);
    }
    
    // Get the actual installed version after upgrade
    final installedVersion = await manager.getInstalledVersion(packageName);
    
    updateState({'packagesProcessed': packagesProcessed + 1});
    final results = Map<String, String>.from(operationResults);
    results[packageName] = 'upgraded:${installedVersion ?? 'unknown'}';
    updateState({'operationResults': results});
  }

  Future<void> _reinstallPackage(PackageManager manager, String packageName, String? version) async {
    logger.info('Reinstalling package: $packageName${version != null ? ' version $version' : ''}');
    emitEvent(ProgressEvent(moduleId: action.id, message: 'Reinstalling package: $packageName'));

    // Uninstall first if installed
    if (await manager.isInstalled(packageName)) {
      await manager.uninstall(packageName);
    }

    // Then install
    // Use appropriate installation method based on configuration and capabilities
    if (installGlobally && manager is GlobalInstallCapability) {
      await manager.installGlobally(packageName, version: version);
    } else if (!installGlobally && manager is LocalInstallCapability) {
      await manager.installLocally(packageName, version: version);
    } else {
      // Fallback to default install method
      await manager.install(packageName, version: version);
    }
    
    // Get the actual installed version after reinstall
    final installedVersion = await manager.getInstalledVersion(packageName);
    
    updateState({'packagesProcessed': packagesProcessed + 1});
    final results = Map<String, String>.from(operationResults);
    results[packageName] = 'reinstalled:${installedVersion ?? 'unknown'}';
    updateState({'operationResults': results});
  }

  @override
  Future<void> rollback() async {
    emitEvent(StartedEvent(moduleId: action.id, message: 'Starting package module rollback'));
    
    try {
      final manager = await _getPackageManager();
      
      // Rollback based on operation type and results
      await _rollbackPackages(manager);
      
      emitEvent(CompletedEvent(moduleId: action.id, message: 'Package module rollback completed'));
    } catch (e) {
      emitEvent(FailedEvent(moduleId: action.id, message: 'Failed to rollback package operation: $e'));
      rethrow;
    }
  }

  Future<void> _rollbackPackages(PackageManager manager) async {
    final results = operationResults;
    if (results.isEmpty) {
      logger.info('No package operations to rollback');
      emitEvent(ProgressEvent(moduleId: action.id, message: 'No package operations to rollback'));
      return;
    }

    logger.info('Rolling back package operations: $results');
    emitEvent(ProgressEvent(moduleId: action.id, message: 'Rolling back ${results.length} packages'));

    for (final entry in results.entries) {
      final packageName = entry.key;
      final result = entry.value;
      
      emitEvent(ProgressEvent(moduleId: action.id, message: 'Rolling back package: $packageName'));
      
      try {
        await _rollbackPackage(manager, packageName, result);
      } catch (e) {
        logger.warning('Failed to rollback package $packageName: $e');
        emitEvent(ProgressEvent(moduleId: action.id, message: 'Failed to rollback package: $packageName'));
        updateState({'errorsEncountered': errorsEncountered + 1});
      }
    }
  }

  Future<void> _rollbackPackage(PackageManager manager, String packageName, String result) async {
    // Parse the result to understand what was done
    if (result.startsWith('installed:')) {
      await _rollbackInstall(manager, packageName);
    } else if (result.startsWith('upgraded:')) {
      await _rollbackUpgrade(manager, packageName);
    } else if (result.startsWith('reinstalled:')) {
      await _rollbackReinstall(manager, packageName);
    } else if (result.startsWith('uninstalled:')) {
      await _rollbackUninstall(manager, packageName);
    } else {
      logger.info('Unknown operation result for $packageName: $result, skipping rollback');
    }
  }

  Future<void> _rollbackInstall(PackageManager manager, String packageName) async {
    logger.info('Rolling back installation of $packageName');
    emitEvent(ProgressEvent(moduleId: action.id, message: 'Uninstalling $packageName'));

    // Check if package is still installed
    bool isInstalled = false;
    if (manager is GlobalLocalContextCapability) {
      isInstalled = installGlobally 
          ? await manager.isInstalledGlobally(packageName)
          : await manager.isInstalledLocally(packageName);
    } else {
      isInstalled = await manager.isInstalled(packageName);
    }

    if (isInstalled) {
      // Use appropriate uninstall method based on installation type
      if (manager is GlobalLocalContextCapability) {
        if (installGlobally) {
          await manager.uninstallGlobally(packageName);
        } else {
          await manager.uninstallLocally(packageName);
        }
      } else {
        await manager.uninstall(packageName);
      }
      logger.info('Successfully uninstalled $packageName');
    } else {
      logger.info('Package $packageName is not installed, skipping uninstall');
    }
  }

  Future<void> _rollbackUpgrade(PackageManager manager, String packageName) async {
    logger.info('Rolling back upgrade of $packageName');
    // For upgrades, we can't easily rollback to the previous version
    // without tracking the original version, so we just log this
    logger.warning('Cannot rollback upgrade of $packageName - original version not tracked');
  }

  Future<void> _rollbackReinstall(PackageManager manager, String packageName) async {
    logger.info('Rolling back reinstall of $packageName');
    // For reinstalls, we can't easily rollback without knowing the original state
    // so we just log this
    logger.warning('Cannot rollback reinstall of $packageName - original state not tracked');
  }

  Future<void> _rollbackUninstall(PackageManager manager, String packageName) async {
    logger.info('Rolling back uninstall of $packageName');
    // For uninstalls, we would need to reinstall the package
    // but we don't track the original version, so we just log this
    logger.warning('Cannot rollback uninstall of $packageName - original version not tracked');
  }
}
