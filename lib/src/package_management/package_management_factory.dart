import 'package:configr/src/package_management/brew.dart';
import 'package:configr/src/package_management/dnf.dart';
import 'package:configr/src/package_management/docker.dart';
import 'package:configr/src/package_management/apt.dart';
import 'package:configr/src/package_management/flatpak.dart';
import 'package:configr/src/package_management/package_manger.dart';
import 'package:configr/src/package_management/pacman.dart';
import 'package:configr/src/package_management/pamac.dart';
import 'package:configr/src/package_management/pip.dart';
import 'package:configr/src/package_management/npm.dart';
import 'package:configr/src/package_management/snap.dart';
import 'package:configr/src/package_management/yum.dart';
import 'package:configr/src/utils/privilege_escalation.dart';

class PackageManagerFactory {
  static PackageManager create(
    String managerName,
    PrivilegeEscalation privilegeEscalation,
  ) {
    switch (managerName.toLowerCase()) {
      case 'apt':
      case 'apt-get':
        return AptPackageManager(privilegeEscalation);
      case 'brew':
      case 'homebrew':
        return BrewPackageManager(privilegeEscalation);
      case 'dnf':
        return DnfPackageManager(privilegeEscalation);
      case 'docker':
        return DockerPackageManager(privilegeEscalation);
      case 'flatpak':
        return FlatpakPackageManager(privilegeEscalation);
      case 'npm':
      case 'npx':
        return NpmPackageManager(privilegeEscalation);
      case 'pacman':
        return PacmanPackageManager(privilegeEscalation);
      case 'pamac':
        return PamacPackageManager(privilegeEscalation);
      case 'pip':
      case 'pip3':
        return PipPackageManager(privilegeEscalation);
      case 'snap':
        return SnapPackageManager(privilegeEscalation);
      case 'yum':
        return YumPackageManager(privilegeEscalation);
      default:
        throw UnsupportedError('Unsupported package manager: $managerName');
    }
  }

  static Future<PackageManager?> detectAvailable(
    PrivilegeEscalation privilegeEscalation,
  ) async {
    // List of package managers to try in order of preference
    final managers = [
      'apt',
      'pacman',
      'pamac',
      'flatpak',
      'brew',
      'snap',
      'npm',
      'docker',
    ];

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
