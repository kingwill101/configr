import 'package:configr/src/package_management/package_manger.dart';
import 'package:configr/src/utils/logging.dart';

class SnapPackageManager extends PackageManager
    with GlobalInstallCapability {
  SnapPackageManager(super.privilegeEscalation);

  @override
  String get name => 'snap';

  @override
  Future<void> install(String packageName, {String? version}) async {
    logger.info('Installing snap package: $packageName');
    final args = ['install', packageName];
    if (version != null) {
      args.add('--channel=$version');
    }
    await runCommand('snap', args);
  }

  @override
  Future<void> installGlobally(String packageName, {String? version}) async {
    await install(packageName, version: version);
  }

  @override
  Future<void> uninstall(String packageName) async {
    logger.info('Uninstalling snap package: $packageName');
    await runCommand('snap', ['remove', packageName]);
  }

  @override
  Future<bool> isInstalled(String packageName) async {
    final result = await runCommand('snap', ['list', packageName]);
    return result.exitCode == 0;
  }

  @override
  Future<String?> getInstalledVersion(String packageName) async {
    final result = await runCommand('snap', ['list', packageName]);
    if (result.exitCode != 0) return null;
    // Output: "Name  Version  Rev  Tracking  Publisher  Notes"
    final lines = result.stdout.toString().split('\n');
    if (lines.length >= 2) {
      final parts = lines[1].trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) return parts[1];
    }
    return null;
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final result = await runCommand('snap', ['--version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
}
