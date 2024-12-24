import 'package:configr/package_management/package_manger.dart';

class PacmanPackageManager extends PackageManager with GlobalInstallCapability {
  PacmanPackageManager(super.privilegeEscalation);

  @override
  String get name => 'pacman';

  @override
  Future<void> install(String packageName, {String? version}) async {
    List<String> command = ['-S', '--noconfirm'];
    if (version != null) {
      command.add('$packageName=$version');
    } else {
      command.add(packageName);
    }
    await runCommand('pacman', command);
  }

  @override
  Future<void> uninstall(String packageName) async {
    await runCommand('pacman', ['-R', '--noconfirm', packageName]);
  }

  @override
  Future<bool> isInstalled(String packageName) async {
    final result = await runCommand('pacman', ['-Q', packageName]);
    return result.exitCode == 0;
  }

  @override
  Future<String?> getInstalledVersion(String packageName) async {
    final result = await runCommand('pacman', ['-Q', packageName]);
    if (result.exitCode == 0) {
      // Output format is "package version"
      final parts = result.stdout.trim().split(' ');
      if (parts.length >= 2) {
        return parts[1];
      }
    }
    return null;
  }

  @override
  Future<void> installGlobally(String packageName, {String? version}) async {
    // For pacman, global installation is the same as regular installation
    await install(packageName, version: version);
  }
}
