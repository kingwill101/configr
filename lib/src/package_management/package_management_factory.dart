// lib/package_management/package_manager_factory.dart

import 'package:configr/src/package_management/docker.dart';
import 'package:configr/src/package_management/apt.dart';
import 'package:configr/src/package_management/package_manger.dart';
import 'package:configr/src/package_management/pacman.dart';
import 'package:configr/src/package_management/pamac.dart';
import 'package:configr/src/package_management/npm.dart';
import 'package:configr/src/utils/privilege_escalation.dart';

class PackageManagerFactory {
  static PackageManager create(
    String managerName,
    PrivilegeEscalation privilegeEscalation,
  ) {
    switch (managerName.toLowerCase()) {
      case 'apt':
        return AptPackageManager(privilegeEscalation);
      case 'pacman':
        return PacmanPackageManager(privilegeEscalation);
      case 'pamac':
        return PamacPackageManager(privilegeEscalation);
      case 'docker':
        return DockerPackageManager(privilegeEscalation);
      case 'npm':
        return NpmPackageManager(privilegeEscalation);
      default:
        throw UnsupportedError('Unsupported package manager: $managerName');
    }
  }

  static Future<PackageManager?> detectAvailable(
    PrivilegeEscalation privilegeEscalation,
  ) async {
    // List of package managers to try in order of preference
    final managers = ['apt', 'pacman', 'pamac', 'npm', 'docker'];

    for (final managerName in managers) {
      try {
        final manager = create(managerName, privilegeEscalation);
        if (await manager.isAvailable()) {
          return manager;
        }
      } catch (e) {
        // Continue to next manager
        continue;
      }
    }

    return null; // No available package manager found
  }
}
