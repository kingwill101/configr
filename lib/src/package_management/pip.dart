import 'package:configr/src/package_management/package_manger.dart';
import 'package:configr/src/utils/logging.dart';

class PipPackageManager extends PackageManager {
  PipPackageManager(super.privilegeEscalation);

  @override
  String get name => 'pip3';

  @override
  Future<void> install(String packageName, {String? version}) async {
    logger.info('Installing pip package: $packageName');
    final args = ['install', packageName];
    await runCommand('pip3', args);
  }

  @override
  Future<void> uninstall(String packageName) async {
    logger.info('Uninstalling pip package: $packageName');
    await runCommand('pip3', ['uninstall', '-y', packageName]);
  }

  @override
  Future<bool> isInstalled(String packageName) async {
    final result = await runCommand('pip3', ['show', packageName]);
    return result.exitCode == 0;
  }

  @override
  Future<String?> getInstalledVersion(String packageName) async {
    final result = await runCommand('pip3', ['show', packageName]);
    if (result.exitCode != 0) return null;
    final versionMatch =
        RegExp(r'Version:\s*(.+)').firstMatch(result.stdout.toString());
    return versionMatch?.group(1)?.trim();
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final result = await runCommand('pip3', ['--version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
}
