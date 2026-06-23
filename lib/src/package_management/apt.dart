// lib/package_management/apt_package_manager.dart
import 'package:configr/src/package_management/package_manger.dart';
import 'package:configr/src/utils/logging.dart';

class AptPackageManager extends PackageManager with GlobalInstallCapability {
  AptPackageManager(super.privilegeEscalation);

  @override
  String get name => 'apt';

  @override
  Future<void> install(String packageName, {String? version}) async {
    List<String> command = ['install', '-y'];
    if (version != null) {
      command.add('$packageName=$version');
    } else {
      command.add(packageName);
    }
    logger.info('Installing apt package: ${command.join(' ')}');
    await runCommand('apt-get', command);
  }

  @override
  Future<void> uninstall(String packageName) async {
    logger.info('Uninstalling apt package: $packageName');
    await runCommand('apt-get', ['remove', '-y', packageName]);
  }

  @override
  Future<bool> isInstalled(String packageName) async {
    final result = await runCommand('dpkg', ['-s', packageName]);
    return result.exitCode == 0;
  }

  @override
  Future<String?> getInstalledVersion(String packageName) async {
    final result = await runCommand('dpkg-query', [
      '-W',
      '-f=\${Version}',
      packageName,
    ]);
    return result.exitCode == 0 ? result.stdout.trim() : null;
  }

  @override
  Future<void> installGlobally(String packageName, {String? version}) async {
    // For apt, global installation is the same as regular installation
    await install(packageName, version: version);
  }

  @override
  Future<void> updateCache() async {
    logger.info('Updating apt cache');
    await runCommand('apt-get', ['update']);
  }

  @override
  Future<void> addRepository(String url) async {
    logger.info('Adding apt repository: $url');
    await runCommand('add-apt-repository', ['-y', url]);
    await updateCache();
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final result = await runCommand('apt-get', ['--version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
}
