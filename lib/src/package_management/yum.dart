import 'package:configr/src/package_management/package_manger.dart';
import 'package:configr/src/utils/logging.dart';

class YumPackageManager extends PackageManager {
  YumPackageManager(super.privilegeEscalation);

  @override
  String get name => 'yum';

  @override
  Future<void> install(String packageName, {String? version}) async {
    logger.info('Installing yum package: $packageName');
    final args = ['install', '-y', packageName];
    await runCommand('yum', args);
  }

  @override
  Future<void> uninstall(String packageName) async {
    logger.info('Uninstalling yum package: $packageName');
    await runCommand('yum', ['remove', '-y', packageName]);
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
    logger.info('Updating yum cache');
    await runCommand('yum', ['makecache']);
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final result = await runCommand('yum', ['--version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
}
