import 'dart:io';

import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/models/command.dart' as cmd_model;
import 'package:configr/src/security/input_sanitizer.dart';
import 'package:configr/src/security/security_manager.dart';
import 'package:configr/src/utils/command_executor.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:configr/src/utils/privilege_escalation.dart'
    show NoPrivilegeEscalation;
import 'package:i3config/i3config_v2.dart' as i3;

/// Block handler for the `package` config action.
///
/// Manages system packages via package managers (apt, brew, etc.).
///
/// ```i3
/// package {
///   source = "curl"
///   operation = "install"    # install | uninstall | upgrade | reinstall
///   package_manager = "apt"
///   force = true
///   skip_if_installed = true
/// }
/// ```
class PackageBlock extends ActionBlock {
  @override
  String get blockType => 'package';

  // ---------------------------------------------------------------------------
  // Package-specific properties
  // ---------------------------------------------------------------------------

  String? manager;
  String packageManager = 'apt';
  String operation = 'install';
  String packages = '';
  bool force = false;
  bool skipIfInstalled = true;
  bool updateCache = true;
  List<String> repositories = [];

  // ---------------------------------------------------------------------------
  // Execution state
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> operationResults = [];
  int packagesProcessed = 0;
  int packagesSkipped = 0;
  int errorsEncountered = 0;
  bool operationSuccess = false;

  PackageBlock({super.fileSystem, super.eventBus});

  // ---------------------------------------------------------------------------
  // Handler pipeline
  // ---------------------------------------------------------------------------

  @override
  Map<String, String> get additionalProperties => {
    'package_manager': ?manager,
    if (packageManager != 'apt') 'package_manager': packageManager,
    if (operation != 'install') 'operation': operation,
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

    manager = (context.getVariable('manager') as String?) ?? manager;
    packageManager =
        (context.getVariable('package_manager') as String?) ?? 'apt';
    operation = (context.getVariable('operation') as String?) ?? 'install';

    // Packages can be from source or the variable
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

  // ---------------------------------------------------------------------------
  // Execution
  // ---------------------------------------------------------------------------

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
      final resolvedManager = _getPackageManager();

      if (updateCache) {
        await _updatePackageCache(resolvedManager);
      }

      if (repositories.isNotEmpty) {
        await _addRepositories(resolvedManager);
      }

      await _performPackageOperations(resolvedManager);

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

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  String _getPackageManager() {
    switch (packageManager.toLowerCase()) {
      case 'apt':
      case 'apt-get':
        return 'apt-get';
      case 'brew':
      case 'homebrew':
        return 'brew';
      case 'yum':
        return 'yum';
      case 'dnf':
        return 'dnf';
      case 'pacman':
        return 'pacman';
      case 'snap':
        return 'snap';
      case 'flatpak':
        return 'flatpak';
      case 'pip':
      case 'pip3':
        return 'pip3';
      case 'npm':
        return 'npm';
      default:
        return packageManager.toLowerCase();
    }
  }

  String _getPrivilegeEscalation() {
    switch (packageManager.toLowerCase()) {
      case 'apt':
      case 'apt-get':
      case 'yum':
      case 'dnf':
      case 'pacman':
        return 'sudo';
      default:
        return '';
    }
  }

  Future<void> _updatePackageCache(String manager) async {
    final escalate = _getPrivilegeEscalation();

    emitEvent(
      StatusUpdateEvent(
        moduleId: id,
        level: StatusEvent.info,
        message: 'Updating package cache ($manager)',
      ),
    );

    if (manager == 'apt-get') {
      await _runCommand(
        [escalate, 'apt-get', 'update'].where((s) => s.isNotEmpty).toList(),
      );
    }
  }

  Future<void> _addRepositories(String manager) async {
    if (manager == 'apt-get') {
      for (final repo in repositories) {
        await _runCommand(['sudo', 'add-apt-repository', '-y', repo]);
      }
      await _updatePackageCache(manager);
    } else if (manager == 'brew') {
      for (final repo in repositories) {
        await _runCommand(['brew', 'tap', repo]);
      }
    }
  }

  Future<void> _performPackageOperations(String manager) async {
    final pkgList = packages
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();

    for (final pkg in pkgList) {
      try {
        switch (operation) {
          case 'install':
            await _installPackage(manager, pkg);
            break;
          case 'uninstall':
            await _uninstallPackage(manager, pkg);
            break;
          case 'upgrade':
            await _upgradePackage(manager, pkg);
            break;
          case 'reinstall':
            await _reinstallPackage(manager, pkg);
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

  Future<bool> _isPackageInstalled(String manager, String pkg) async {
    try {
      switch (manager) {
        case 'apt-get':
          final result = await _runCommand(['dpkg', '-l', pkg]);
          return result.exitCode == 0;
        case 'brew':
          final result = await _runCommand(['brew', 'list', pkg]);
          return result.exitCode == 0;
        case 'pip3':
          final result = await _runCommand(['pip3', 'show', pkg]);
          return result.exitCode == 0;
        case 'npm':
          final result = await _runCommand(['npm', 'list', '-g', pkg]);
          return result.exitCode == 0;
        default:
          return false;
      }
    } catch (_) {
      return false;
    }
  }

  Future<void> _installPackage(String manager, String pkg) async {
    if (skipIfInstalled && await _isPackageInstalled(manager, pkg)) {
      packagesSkipped++;
      return;
    }

    final escalate = _getPrivilegeEscalation();
    List<String> args;

    switch (manager) {
      case 'apt-get':
        args = [escalate, 'apt-get', 'install', '-y'];
        if (force) args.add('--force-yes');
        args.add(pkg);
        break;
      case 'brew':
        args = ['brew', 'install'];
        if (force) args.add('--force');
        args.add(pkg);
        break;
      case 'pip3':
        args = ['pip3', 'install'];
        if (force) args.add('--force-reinstall');
        args.add(pkg);
        break;
      case 'npm':
        args = ['npm', 'install', '-g'];
        if (force) args.add('--force');
        args.add(pkg);
        break;
      default:
        args = [
          escalate,
          manager,
          'install',
          '-y',
          pkg,
        ].where((s) => s.isNotEmpty).toList();
    }

    await _runCommand(args.where((s) => s.isNotEmpty).toList());
    operationResults.add({
      'package': pkg,
      'operation': 'install',
      'success': true,
    });
  }

  Future<void> _uninstallPackage(String manager, String pkg) async {
    final escalate = _getPrivilegeEscalation();
    List<String> args;

    switch (manager) {
      case 'apt-get':
        args = [
          escalate,
          'apt-get',
          'remove',
          '-y',
          pkg,
        ].where((s) => s.isNotEmpty).toList();
        break;
      case 'brew':
        args = ['brew', 'uninstall', pkg];
        break;
      case 'pip3':
        args = ['pip3', 'uninstall', '-y', pkg];
        break;
      case 'npm':
        args = ['npm', 'uninstall', '-g', pkg];
        break;
      default:
        args = [
          escalate,
          manager,
          'remove',
          '-y',
          pkg,
        ].where((s) => s.isNotEmpty).toList();
    }

    await _runCommand(args);
    operationResults.add({
      'package': pkg,
      'operation': 'uninstall',
      'success': true,
    });
  }

  Future<void> _upgradePackage(String manager, String pkg) async {
    final escalate = _getPrivilegeEscalation();
    List<String> args;

    switch (manager) {
      case 'apt-get':
        args = [
          escalate,
          'apt-get',
          'upgrade',
          '-y',
          pkg,
        ].where((s) => s.isNotEmpty).toList();
        break;
      case 'brew':
        args = ['brew', 'upgrade', pkg];
        break;
      case 'pip3':
        args = ['pip3', 'install', '--upgrade', pkg];
        break;
      case 'npm':
        args = ['npm', 'update', '-g', pkg];
        break;
      default:
        args = [
          escalate,
          manager,
          'upgrade',
          '-y',
          pkg,
        ].where((s) => s.isNotEmpty).toList();
    }

    await _runCommand(args);
    operationResults.add({
      'package': pkg,
      'operation': 'upgrade',
      'success': true,
    });
  }

  Future<void> _reinstallPackage(String manager, String pkg) async {
    await _uninstallPackage(manager, pkg);
    await _installPackage(manager, pkg);
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
    await _uninstallPackage(packageManager, pkg);
  }

  Future<void> _rollbackUpgrade(String pkg) async {
    // Cannot easily rollback upgrades — log warning
    logger.warning('Cannot fully rollback upgrade of $pkg');
  }

  Future<void> _rollbackReinstall(String pkg) async {
    // Reinstall is essentially re-doing, rollback is reinstall previous version
    logger.warning('Rollback of reinstall for $pkg not fully supported');
  }

  Future<void> _rollbackUninstall(String pkg) async {
    await _installPackage(packageManager, pkg);
  }

  Future<ProcessResult> _runCommand(List<String> args) async {
    final executable = args.first;
    final cmdArgs = args.length > 1 ? args.sublist(1) : <String>[];

    // Strip privilege escalation prefix — let CommandExecutor /
    // PrivilegeEscalation handle it through the proper channel.
    final strippedExecutable =
        executable == 'sudo' && cmdArgs.isNotEmpty ? cmdArgs.removeAt(0) : executable;

    final command = cmd_model.Command(
      name: 'package_${operation}_$id',
      id: id,
      command: strippedExecutable,
      parameters: cmdArgs,
    );

    final escalation = privilegeEscalation ?? NoPrivilegeEscalation();
    final result = await CommandExecutor.execute(
      command,
      escalation,
      securityManager: SecurityManager(),
      inputSanitizer: InputSanitizer(),
    );

    if (result.exitCode != 0) {
      throw ActionFailedException(
        'Command failed: ${args.join(' ')}\n${result.stderr}',
        moduleId: id,
      );
    }

    return result;
  }
}
