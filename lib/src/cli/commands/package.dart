import 'dart:convert';

import 'package:configr/src/cli/commands/base_command.dart';
import 'package:configr/src/configr_runtime.dart';
import 'package:configr/src/models/package_lock_data.dart';
import 'package:configr/src/package_management/apt.dart';
import 'package:configr/src/package_management/brew.dart';
import 'package:configr/src/package_management/dnf.dart';
import 'package:configr/src/package_management/docker.dart';
import 'package:configr/src/package_management/flatpak.dart';
import 'package:configr/src/package_management/npm.dart';
import 'package:configr/src/package_management/pacman.dart';
import 'package:configr/src/package_management/pamac.dart';
import 'package:configr/src/package_management/package_manger.dart';
import 'package:configr/src/package_management/pip.dart';
import 'package:configr/src/package_management/snap.dart';
import 'package:configr/src/package_management/yum.dart';
import 'package:configr/src/utils/package_lock_manager.dart';
import 'package:configr/src/utils/privilege_escalation.dart';
import 'package:artisanal/args.dart';

// ---------------------------------------------------------------------------
// PackageCommand — top-level `configr package`
// ---------------------------------------------------------------------------

class PackageCommand extends BaseCommand {
  @override
  String get name => 'package';

  @override
  String get description => 'Manage packages defined in configuration';

  PackageCommand() {
    addSubcommand(PackageListCommand());
    addSubcommand(PackageUpdateCommand());
    addSubcommand(PackageUpgradeCommand());
    addSubcommand(PackageLockCommand());
  }

  @override
  Future<void> executeCommand() async {
    io.title('Package Management');
    io.line('Usage: configr package <subcommand>');
    io.line('');
    io.line('Subcommands:');
    for (final cmd in subcommands.values) {
      io.line('  ${cmd.name}  ${cmd.description}');
    }
  }
}

// ---------------------------------------------------------------------------
// Helpers used by subcommands
// ---------------------------------------------------------------------------

ConfigrRuntime _runtimeFor(Command<void> cmd) =>
    (cmd.parent as PackageCommand).runtime;

PackageManager? _createManager(String blockType) {
  final escalation = NoPrivilegeEscalation();
  return switch (blockType) {
    'apt' => AptPackageManager(escalation),
    'pacman' => PacmanPackageManager(escalation),
    'brew' => BrewPackageManager(escalation),
    'dnf' => DnfPackageManager(escalation),
    'yum' => YumPackageManager(escalation),
    'snap' => SnapPackageManager(escalation),
    'flatpak' => FlatpakPackageManager(escalation),
    'npm' => NpmPackageManager(escalation),
    'pip' => PipPackageManager(escalation),
    'docker' => DockerPackageManager(escalation),
    'pamac' => PamacPackageManager(escalation),
    _ => null,
  };
}

List<String> _packagesFromSource(String source) =>
    source.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();

/// Compute a content hash for the config file.
String _contentHash(String content) {
  final bytes = utf8.encode(content);
  return base64Encode(bytes).substring(0, _min(32, base64Encode(bytes).length));
}

int _min(int a, int b) => a < b ? a : b;

/// Get the effective package lockfile path for a runtime.
String _lockPathFor(ConfigrRuntime runtime) {
  return PackageLockManager.lockPathFor(runtime.resolvedConfigPath);
}

// ===========================================================================
// Subcommand: list
// ===========================================================================

class PackageListCommand extends Command<void> {
  @override
  String get name => 'list';

  @override
  String get description => 'List packages defined in configuration';

  @override
  Future<void> run() async {
    final runtime = _runtimeFor(this);
    io.title('Configured Packages');

    final blocks = await runtime.parseAndCollect();
    final managers = <_ManagerBlock>[];
    for (final block in blocks) {
      if (_createManager(block.blockType) == null) continue;
      final pkgs = _packagesFromSource(block.source);
      if (pkgs.isEmpty) continue;
      managers.add(_ManagerBlock(block.blockType, pkgs));
    }

    if (managers.isEmpty) {
      io.warn('No package blocks found in configuration.');
      io.line('');
      io.line('Define packages in your config file, e.g.:');
      io.line('  apt {');
      io.line('    source = "curl vim git"');
      io.line('  }');
      return;
    }

    var totalPkgs = 0;
    for (final mgr in managers) {
      totalPkgs += mgr.packages.length;
    }

    io.section(
      '${managers.length} manager(s), $totalPkgs package(s) configured:',
    );
    for (final mgr in managers) {
      io.line('  ${mgr.blockType}:');
      for (final pkg in mgr.packages) {
        io.line('    - $pkg');
      }
    }
  }
}

// ===========================================================================
// Subcommand: update
// ===========================================================================

class PackageUpdateCommand extends Command<void> {
  @override
  String get name => 'update';

  @override
  String get description => 'Update package caches for all configured managers';

  @override
  Future<void> run() async {
    final runtime = _runtimeFor(this);
    io.title('Package Cache Update');

    final blocks = await runtime.parseAndCollect();
    final managerTypes = <String>{};
    for (final block in blocks) {
      if (_createManager(block.blockType) != null &&
          _packagesFromSource(block.source).isNotEmpty) {
        managerTypes.add(block.blockType);
      }
    }

    if (managerTypes.isEmpty) {
      io.warn('No package blocks found in configuration.');
      return;
    }

    var successCount = 0;
    var failCount = 0;

    for (final mgrType in managerTypes) {
      final pm = _createManager(mgrType);
      if (pm == null) {
        io.warn('  $mgrType: no manager implementation available');
        continue;
      }

      io.write('  $mgrType: updating cache...');
      try {
        await pm.updateCache();
        io.line(' done');
        successCount++;
      } catch (e) {
        io.line(' failed');
        io.line('          $e');
        failCount++;
      }
    }

    io.line('');
    if (failCount == 0) {
      io.success('Cache update complete — $successCount manager(s) updated.');
    } else {
      io.warn(
        'Cache update finished — $successCount succeeded, $failCount failed.',
      );
    }
  }
}

// ===========================================================================
// Subcommand: upgrade
// ===========================================================================

class _ManagerBlock {
  final String blockType;
  final List<String> packages;
  const _ManagerBlock(this.blockType, this.packages);
}

class PackageUpgradeCommand extends Command<void> {
  PackageUpgradeCommand() {
    argParser.addFlag(
      'dry-run',
      help: 'Show what would be upgraded without making changes',
      defaultsTo: false,
    );
  }

  @override
  String get name => 'upgrade';

  @override
  String get description => 'Upgrade packages defined in configuration';

  @override
  Future<void> run() async {
    final runtime = _runtimeFor(this);
    final dryRun = argResults?['dry-run'] as bool? ?? false;

    io.title('Package Upgrade');

    final blocks = await runtime.parseAndCollect();
    final managers = <_ManagerBlock>[];
    for (final block in blocks) {
      if (_createManager(block.blockType) == null) continue;
      final pkgs = _packagesFromSource(block.source);
      if (pkgs.isEmpty) continue;
      managers.add(_ManagerBlock(block.blockType, pkgs));
    }

    if (managers.isEmpty) {
      io.warn('No package blocks found in configuration.');
      return;
    }

    final records = <PackageLockRecord>[];
    var totalUpgraded = 0;
    var totalSkipped = 0;
    var totalErrors = 0;

    for (final mgr in managers) {
      final pm = _createManager(mgr.blockType);
      if (pm == null) {
        io.warn('  ${mgr.blockType}: no manager implementation available');
        continue;
      }

      io.section('${mgr.blockType} (${mgr.packages.length} package(s))');

      for (final pkg in mgr.packages) {
        if (dryRun) {
          io.line('  [DRY-RUN] $pkg would be upgraded');
          totalSkipped++;
          continue;
        }

        String? oldVersion;
        String? newVersion;
        try {
          oldVersion = await pm.getInstalledVersion(pkg) ?? '(unknown)';
          if (oldVersion != '(unknown)') {
            io.write('  $pkg: $oldVersion → ');
          } else {
            io.write('  $pkg: installing... ');
          }

          await pm.install(pkg);
          newVersion = await pm.getInstalledVersion(pkg) ?? '(unknown)';
          io.line(newVersion);

          records.add(PackageLockRecord(
            name: pkg,
            manager: mgr.blockType,
            version: newVersion,
            appliedAt: DateTime.now().toUtc().toIso8601String(),
          ));
          totalUpgraded++;
        } catch (e) {
          io.line('failed');
          io.line('         $e');
          totalErrors++;
        }
      }
    }

    io.line('');
    if (dryRun) {
      io.info('[DRY-RUN] Would upgrade $totalSkipped package(s).');
    } else {
      if (totalErrors == 0) {
        io.success(
          'Upgrade complete — $totalUpgraded upgraded, '
          '$totalSkipped skipped.',
        );
      } else {
        io.warn(
          'Upgrade finished — $totalUpgraded upgraded, '
          '$totalSkipped skipped, $totalErrors errors.',
        );
      }

      if (records.isNotEmpty) {
        await _writeLockfile(runtime, records, io);
      }
    }
  }
}

// ===========================================================================
// Subcommand: lock
// ===========================================================================

class PackageLockCommand extends Command<void> {
  @override
  String get name => 'lock';

  @override
  String get description =>
      'Record current installed package versions to lockfile';

  @override
  Future<void> run() async {
    final runtime = _runtimeFor(this);
    io.title('Package Lock');

    final blocks = await runtime.parseAndCollect();
    final managers = <_ManagerBlock>[];
    for (final block in blocks) {
      if (_createManager(block.blockType) == null) continue;
      final pkgs = _packagesFromSource(block.source);
      if (pkgs.isEmpty) continue;
      managers.add(_ManagerBlock(block.blockType, pkgs));
    }

    if (managers.isEmpty) {
      io.warn('No package blocks found in configuration.');
      return;
    }

    final records = <PackageLockRecord>[];
    var successCount = 0;
    var errorCount = 0;

    for (final mgr in managers) {
      final pm = _createManager(mgr.blockType);
      if (pm == null) {
        io.warn('  ${mgr.blockType}: no manager implementation available');
        continue;
      }

      io.section('${mgr.blockType} (${mgr.packages.length} package(s))');

      for (final pkg in mgr.packages) {
        try {
          final version = await pm.getInstalledVersion(pkg);
          final versionStr = version ?? '(not installed)';
          io.line('  $pkg: $versionStr');
          records.add(PackageLockRecord(
            name: pkg,
            manager: mgr.blockType,
            version: version,
            appliedAt: DateTime.now().toUtc().toIso8601String(),
          ));
          successCount++;
        } catch (e) {
          io.line('  $pkg: error — $e');
          errorCount++;
        }
      }
    }

    if (records.isNotEmpty) {
      await _writeLockfile(runtime, records, io);
    }

    io.line('');
    if (errorCount == 0) {
      io.success('Lock complete — $successCount package(s) recorded.');
    } else {
      io.warn(
        'Lock finished — $successCount recorded, $errorCount errors.',
      );
    }
  }
}

// ===========================================================================
// Lockfile writing
// ===========================================================================

Future<void> _writeLockfile(
  ConfigrRuntime runtime,
  List<PackageLockRecord> records,
  dynamic io,
) async {
  final lockPath = _lockPathFor(runtime);
  final mgr = PackageLockManager(lockPath, fileSystem: runtime.fileSystem);

  String? configChecksum;
  try {
    final configFile = runtime.fileSystem.file(runtime.resolvedConfigPath);
    if (await configFile.exists()) {
      final content = await configFile.readAsString();
      configChecksum = _contentHash(content);
    }
  } catch (_) {}

  await mgr.write(PackageLockData(
    packages: records,
    configChecksum: configChecksum,
  ));

  io.info('Lockfile written to $lockPath');
}
