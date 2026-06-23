import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/package_management/package_manger.dart';
import 'package:configr/src/utils/command_executor.dart';
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
    packageManager = blockType;
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

  Map<String, String?> _installedVersions = {};
  List<String> _packageList = [];

  @override
  Map<String, dynamic>? get lockfileMetadata {
    if (_installedVersions.isEmpty) return null;
    return {
      'installed_packages': _installedVersions.map(
        (key, value) => MapEntry(key, value),
      ),
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
    packagesProcessed = 0;
    packagesSkipped = 0;
    errorsEncountered = 0;
    operationSuccess = false;
    _installedVersions = {};
    _packageList = [];
  }

  PackageManager createManager();

  CommandOutputHandler? _pmOutput;

  CommandOutputHandler _makeOutputHandler() {
    return (line, isStderr) {
      emitEvent(
        StatusUpdateEvent(
          moduleId: id,
          level: isStderr ? StatusEvent.warning : StatusEvent.info,
          message: line,
        ),
      );
    };
  }

  void _attachOutput(PackageManager pm) {
    _pmOutput = _makeOutputHandler();
    pm.onOutput = _pmOutput;
  }

  void _detachOutput(PackageManager pm) {
    pm.onOutput = null;
    _pmOutput = null;
  }

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
      if (errorsEncountered > 0) {
        emitEvent(
          FailedEvent(
            moduleId: id,
            message:
                'Package $operation completed with $errorsEncountered error(s): '
                '$packagesProcessed processed, $packagesSkipped skipped',
          ),
        );
        throw ActionFailedException(
          'Package $operation failed: $packages',
          moduleId: id,
        );
      }
      if (operation == 'install' || operation == 'reinstall') {
        for (final pkg in _packageList) {
          final version = await pm.getInstalledVersion(pkg);
          if (version != null) {
            _installedVersions[pkg] = version;
          }
        }
      }
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
    emitEvent(
      StartedEvent(moduleId: id, message: 'Rolling back package $operation'),
    );
    try {
      final pm = createManager();
      final pkgList = source
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .toList();
      var uninstalled = 0;
      for (final pkg in pkgList) {
        _attachOutput(pm);
        try {
          await pm.uninstall(pkg);
        } finally {
          _detachOutput(pm);
        }
        uninstalled++;
      }
      emitEvent(
        CompletedEvent(
          moduleId: id,
          message: 'Package rollback completed: $uninstalled uninstalled',
        ),
      );
    } catch (e, _) {
      emitEvent(
        FailedEvent(moduleId: id, message: 'Package rollback failed: $e'),
      );
      rethrow;
    }
  }

  Future<void> _performPackageOperations(PackageManager pm) async {
    _packageList = packages
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    for (final pkg in _packageList) {
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
    _attachOutput(pm);
    try {
      if (scope == 'global' && pm is GlobalInstallCapability) {
        await pm.installGlobally(pkg);
      } else {
        await pm.install(pkg);
      }
    } finally {
      _detachOutput(pm);
    }
  }

  Future<void> _uninstallPackage(PackageManager pm, String pkg) async {
    _attachOutput(pm);
    try {
      if (scope == 'global' && pm is GlobalLocalContextCapability) {
        await pm.uninstallGlobally(pkg);
      } else {
        await pm.uninstall(pkg);
      }
    } finally {
      _detachOutput(pm);
    }
  }

  Future<void> _upgradePackage(PackageManager pm, String pkg) async {
    _attachOutput(pm);
    try {
      await pm.install(pkg);
    } finally {
      _detachOutput(pm);
    }
  }

  Future<void> _reinstallPackage(PackageManager pm, String pkg) async {
    _attachOutput(pm);
    try {
      await pm.uninstall(pkg);
      await pm.install(pkg);
    } finally {
      _detachOutput(pm);
    }
  }

}
