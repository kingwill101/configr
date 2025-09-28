import 'dart:io';
import 'package:configr/events/module_events.dart';
import 'package:configr/exceptions.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/package_management/package_management_factory.dart';
import 'package:configr/package_management/package_manger.dart';
import 'package:configr/utils/event_bus.dart';
import 'package:configr/utils/logging.dart';
import 'package:configr/utils/privellage_escallation.dart';

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
      {super.allowedActions = const ['package'], super.fileSystem}) {
    updateState({
      'packageManager': 'auto',
      'packages': [],
      'packageVersions': {},
      'repositories': [],
      'operation': 'install',
      'force': false,
      'updateCache': true,
      'skipIfInstalled': true,
      'packageId': 0,
      'operationResults': {},
      'packagesProcessed': 0,
      'packagesSkipped': 0,
      'errorsEncountered': 0,
    });
    _loadConfiguration();
  }

  void _loadConfiguration() {
    final props = action.properties;
    
    updateState({
      'packageManager': props['package_manager'] ?? packageManager,
      'operation': props['operation'] ?? operation,
      'force': props['force'] ?? force,
      'updateCache': props['update_cache'] ?? updateCache,
      'skipIfInstalled': props['skip_if_installed'] ?? skipIfInstalled,
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
    if (skipIfInstalled && await manager.isInstalled(packageName)) {
      logger.info('Package $packageName is already installed, skipping');
      updateState({'packagesSkipped': packagesSkipped + 1});
      return;
    }

    logger.info('Installing package: $packageName${version != null ? ' version $version' : ''}');
    emitEvent(ProgressEvent(moduleId: action.id, message: 'Installing package: $packageName'));

    await manager.install(packageName, version: version);
    
    updateState({'packagesProcessed': packagesProcessed + 1});
    final results = Map<String, String>.from(operationResults);
    results[packageName] = 'installed${version != null ? ':$version' : ''}';
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
    await manager.install(packageName, version: version);
    
    updateState({'packagesProcessed': packagesProcessed + 1});
    final results = Map<String, String>.from(operationResults);
    results[packageName] = 'upgraded${version != null ? ':$version' : ''}';
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
    await manager.install(packageName, version: version);
    
    updateState({'packagesProcessed': packagesProcessed + 1});
    final results = Map<String, String>.from(operationResults);
    results[packageName] = 'reinstalled${version != null ? ':$version' : ''}';
    updateState({'operationResults': results});
  }

  @override
  Future<void> rollback() async {
    emitEvent(StartedEvent(moduleId: action.id, message: 'Starting package module rollback'));
    
    try {
      // For package operations, rollback is complex as we don't track original state
      // This is a simplified rollback that logs the operation
      logger.info('Package rollback: This operation cannot be fully rolled back as original package states are not tracked');
      logger.info('Package operation results: $operationResults');
      
      emitEvent(CompletedEvent(moduleId: action.id, message: 'Package module rollback completed (limited rollback capability)'));
    } catch (e) {
      emitEvent(FailedEvent(moduleId: action.id, message: 'Failed to rollback package operation: $e'));
      rethrow;
    }
  }
}
