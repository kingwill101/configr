import 'package:configr/src/package_management/package_manger.dart';
import 'package:configr/src/utils/logging.dart';

class DnfPackageManager extends PackageManager
    with GlobalInstallCapability {
  DnfPackageManager(super.privilegeEscalation);

  @override
  String get name => 'dnf';

  @override
  Future<void> install(String packageName, {String? version}) async {
    logger.info('Installing dnf package: $packageName');
    final args = ['install', '-y', packageName];
    await runCommand('dnf', args);
  }

  @override
  Future<void> installGlobally(String packageName, {String? version}) async {
    await install(packageName, version: version);
  }

  @override
  Future<void> uninstall(String packageName) async {
    logger.info('Uninstalling dnf package: $packageName');
    await runCommand('dnf', ['remove', '-y', packageName]);
  }

  @override
  Future<bool> isInstalled(String packageName) async {
    final result = await runCommand('rpm', ['-q', packageName]);
    return result.exitCode == 0;
  }

  @override
  Future<String?> getInstalledVersion(String packageName) async {
    final result = await runCommand('rpm', ['-q', '--queryformat=%{VERSION}', packageName]);
    return result.exitCode == 0 ? result.stdout.toString().trim() : null;
  }

  @override
  Future<void> updateCache() async {
    logger.info('Updating dnf cache');
    await runCommand('dnf', ['makecache']);
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final result = await runCommand('dnf', ['--version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
}
