import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/package_management/package_manger.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:i3config/i3config_v2.dart' as i3;

import '../action_block.dart';

abstract class BasePackageBlock extends ActionBlock {
  String packageManager = 'apt';
  String operation = 'install';
  String packages = '';
  String scope = 'local';
  bool force = false;
  bool skipIfInstalled = true;
  bool updateCache = true;
  List<String> repositories = [];

  List<Map<String, dynamic>> operationResults = [];
  int packagesProcessed = 0;
  int packagesSkipped = 0;
  int errorsEncountered = 0;
  bool operationSuccess = false;

  @override
  Map<String, String> get additionalProperties => {
    if (packageManager != 'apt') 'package_manager': packageManager,
    if (operation != 'install') 'operation': operation,
    if (scope != 'local') 'scope': scope,
    if (packages.isNotEmpty) 'packages': packages,
    if (repositories.isNotEmpty) 'repositories': repositories.join(', '),
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (force) 'force': force,
    if (!skipIfInstalled) 'skip_if_installed': skipIfInstalled,
    if (!updateCache) 'update_cache': updateCache,
  };

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    operation = (context.getVariable('operation') as String?) ?? 'install';
    scope = (context.getVariable('scope') as String?) ?? 'local';
    packages = source.isNotEmpty ? source : '';
    final pkgVar = context.getVariable('packages');
    if (pkgVar is String && packages.isEmpty) packages = pkgVar;
    if (pkgVar is List) packages = pkgVar.join(' ');
    force = switch (context.getVariable('force')) {
      true || 'true' => true,
      _ => false,
    };
    skipIfInstalled = switch (context.getVariable('skip_if_installed')) {
      false || 'false' => false,
      _ => true,
    };
    updateCache = switch (context.getVariable('update_cache')) {
      false || 'false' => false,
      _ => true,
    };
  }

  @override
  String dryRunSummary() {
    if (packages.isNotEmpty) {
      return '$blockType[$operation]: $packages';
    }
    return '$blockType[$operation]';
  }

  @override
  void resetState() {
    super.resetState();
    packageManager = 'apt';
    operation = 'install';
    packages = '';
    scope = 'local';
    force = false;
    skipIfInstalled = true;
    updateCache = true;
    repositories = [];
    operationResults = [];
    packagesProcessed = 0;
    packagesSkipped = 0;
    errorsEncountered = 0;
    operationSuccess = false;
  }

  PackageManager createManager();

  @override
  Future<void> execute() async {
    emitEvent(
      StartedEvent(
        moduleId: id,
        message: 'Starting package $operation: $packages via $packageManager',
      ),
    );
    if (packages.isEmpty) {
      throw ActionFailedException(
        'No packages specified for $operation',
        moduleId: id,
      );
    }
    try {
      final pm = createManager();
      if (updateCache) {
        emitEvent(
          StatusUpdateEvent(
            moduleId: id,
            level: StatusEvent.info,
            message: 'Updating package cache ($packageManager)',
          ),
        );
        await pm.updateCache();
      }
      if (repositories.isNotEmpty) {
        for (final repo in repositories) {
          await pm.addRepository(repo);
        }
      }
      await _performPackageOperations(pm);
      operationSuccess = true;
      emitEvent(
        CompletedEvent(
          moduleId: id,
          message:
              'Package $operation completed: '
              '$packagesProcessed processed, $packagesSkipped skipped',
        ),
      );
    } catch (e, _) {
      emitEvent(
        FailedEvent(moduleId: id, message: 'Package $operation failed: $e'),
      );
      throw ActionFailedException(
        'Package $operation failed: $packages',
        cause: e,
        moduleId: id,
      );
    }
    status = 'completed';
  }

  @override
  Future<void> rollback() async {
    if (!operationSuccess) return;
    emitEvent(
      StartedEvent(moduleId: id, message: 'Rolling back package $operation'),
    );
    try {
      await _rollbackPackages();
      emitEvent(
        CompletedEvent(moduleId: id, message: 'Package rollback completed'),
      );
    } catch (e, _) {
      emitEvent(
        FailedEvent(moduleId: id, message: 'Package rollback failed: $e'),
      );
      rethrow;
    }
  }

  Future<void> _performPackageOperations(PackageManager pm) async {
    final pkgList = packages
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    for (final pkg in pkgList) {
      try {
        switch (operation) {
          case 'install':
            await _installPackage(pm, pkg);
            break;
          case 'uninstall':
            await _uninstallPackage(pm, pkg);
            break;
          case 'upgrade':
            await _upgradePackage(pm, pkg);
            break;
          case 'reinstall':
            await _reinstallPackage(pm, pkg);
            break;
        }
        packagesProcessed++;
      } catch (e) {
        errorsEncountered++;
        logger.severe('Failed to $operation package $pkg: $e');
        operationResults.add({
          'package': pkg,
          'operation': operation,
          'success': false,
          'error': e.toString(),
        });
      }
    }
  }

  Future<void> _installPackage(PackageManager pm, String pkg) async {
    if (skipIfInstalled) {
      if (scope == 'global' && pm is GlobalLocalContextCapability) {
        if (await pm.isInstalledGlobally(pkg)) {
          packagesSkipped++;
          return;
        }
      } else if (await pm.isInstalled(pkg)) {
        packagesSkipped++;
        return;
      }
    }
    if (scope == 'global' && pm is GlobalInstallCapability) {
      await pm.installGlobally(pkg);
    } else {
      await pm.install(pkg);
    }
    operationResults.add({
      'package': pkg,
      'operation': 'install',
      'success': true,
    });
  }

  Future<void> _uninstallPackage(PackageManager pm, String pkg) async {
    if (scope == 'global' && pm is GlobalLocalContextCapability) {
      await pm.uninstallGlobally(pkg);
    } else {
      await pm.uninstall(pkg);
    }
    operationResults.add({
      'package': pkg,
      'operation': 'uninstall',
      'success': true,
    });
  }

  Future<void> _upgradePackage(PackageManager pm, String pkg) async {
    await pm.install(pkg);
    operationResults.add({
      'package': pkg,
      'operation': 'upgrade',
      'success': true,
    });
  }

  Future<void> _reinstallPackage(PackageManager pm, String pkg) async {
    await pm.uninstall(pkg);
    await pm.install(pkg);
    operationResults.add({
      'package': pkg,
      'operation': 'reinstall',
      'success': true,
    });
  }

  Future<void> _rollbackPackages() async {
    for (final result in operationResults.reversed) {
      final pkg = result['package'] as String;
      final op = result['operation'] as String;
      try {
        switch (op) {
          case 'install':
            await _rollbackInstall(pkg);
            break;
          case 'upgrade':
            await _rollbackUpgrade(pkg);
            break;
          case 'uninstall':
            await _rollbackUninstall(pkg);
            break;
          case 'reinstall':
            await _rollbackReinstall(pkg);
            break;
        }
      } catch (e) {
        logger.severe('Failed to rollback $op for $pkg: $e');
      }
    }
  }

  Future<void> _rollbackInstall(String pkg) async {
    final pm = createManager();
    await pm.uninstall(pkg);
  }

  Future<void> _rollbackUpgrade(String pkg) async {
    logger.warning('Cannot fully rollback upgrade of $pkg');
  }

  Future<void> _rollbackReinstall(String pkg) async {
    logger.warning('Rollback of reinstall for $pkg not fully supported');
  }

  Future<void> _rollbackUninstall(String pkg) async {
    final pm = createManager();
    await pm.install(pkg);
  }
}
