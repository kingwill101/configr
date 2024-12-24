// lib/package_management/apt_package_manager.dart
import 'package:configr/package_management/package_manger.dart';

class AptPackageManager extends PackageManager with GlobalInstallCapability {
  AptPackageManager(super.privilegeEscalation);

  @override
  String get name => 'apt';

  @override
  Future<void> install(String packageName, {String? version}) async {
    List<String> command = ['apt-get', 'install', '-y'];
    if (version != null) {
      command.add('$packageName=$version');
    } else {
      command.add(packageName);
    }
    await runCommand('apt-get', command);
  }

  @override
  Future<void> uninstall(String packageName) async {
    await runCommand('apt-get', ['remove', '-y', packageName]);
  }

  @override
  Future<bool> isInstalled(String packageName) async {
    final result = await runCommand('dpkg', ['-s', packageName]);
    return result.exitCode == 0;
  }

  @override
  Future<String?> getInstalledVersion(String packageName) async {
    final result =
        await runCommand('dpkg-query', ['-W', '-f=\${Version}', packageName]);
    return result.exitCode == 0 ? result.stdout.trim() : null;
  }

  @override
  Future<void> installGlobally(String packageName, {String? version}) async {
    // For apt, global installation is the same as regular installation
    await install(packageName, version: version);
  }
}
