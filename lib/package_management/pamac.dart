import 'package:configr/package_management/package_manger.dart';

class PamacPackageManager extends PackageManager
    with GlobalInstallCapability, VersionLockCapability {
  PamacPackageManager(super.privilegeEscalation);

  @override
  String get name => 'pamac';

  @override
  Future<void> install(String packageName, {String? version}) async {
    List<String> command = ['install', '--no-confirm'];
    if (version != null) {
      command.add('$packageName=$version');
    } else {
      command.add(packageName);
    }
    await runCommand('pamac', command);
  }

  @override
  Future<void> uninstall(String packageName) async {
    await runCommand('pamac', ['remove', '--no-confirm', packageName]);
  }

  @override
  Future<bool> isInstalled(String packageName) async {
    final result =
        await runCommand('pamac', ['list', '--installed', packageName]);
    return result.exitCode == 0;
  }

  @override
  Future<String?> getInstalledVersion(String packageName) async {
    final result =
        await runCommand('pamac', ['list', '--installed', packageName]);
    if (result.exitCode == 0) {
      // Output format: "package version description"
      final parts = result.stdout.trim().split(' ');
      if (parts.length >= 2) {
        return parts[1];
      }
    }
    return null;
  }

  @override
  Future<void> installGlobally(String packageName, {String? version}) async {
    // For pamac, global installation is the same as regular installation
    await install(packageName, version: version);
  }

  @override
  Future<void> lockVersion(String packageName, String version) async {
    // Lock package version by adding it to pacman's IgnorePkg
    await runCommand('pamac', ['hold', packageName]);
  }
}
