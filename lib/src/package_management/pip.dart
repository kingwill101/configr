import 'package:configr/src/package_management/package_manger.dart';
import 'package:configr/src/utils/logging.dart';

class PipPackageManager extends PackageManager
    with
        GlobalInstallCapability,
        LocalInstallCapability,
        GlobalLocalContextCapability {
  PipPackageManager(super.privilegeEscalation);

  @override
  String get name => 'pip3';

  @override
  Future<void> install(String packageName, {String? version}) async {
    logger.info('Installing pip package: $packageName');
    final args = [
      'install',
      if (version != null) '$packageName==$version' else packageName,
    ];
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
    return _parseVersion(result.stdout.toString());
  }

  @override
  Future<void> installGlobally(String packageName, {String? version}) async {
    await install(packageName, version: version);
  }

  @override
  Future<void> installLocally(String packageName, {String? version}) async {
    logger.info('Installing pip package locally: $packageName');
    final args = [
      'install',
      '--user',
      if (version != null) '$packageName==$version' else packageName,
    ];
    await runCommand('pip3', args);
  }

  @override
  Future<bool> isInstalledGlobally(String packageName) async {
    return isInstalled(packageName);
  }

  @override
  Future<bool> isInstalledLocally(String packageName) async {
    final result = await runCommand('pip3', ['show', '--user', packageName]);
    return result.exitCode == 0;
  }

  @override
  Future<String?> getInstalledVersionGlobally(String packageName) async {
    return getInstalledVersion(packageName);
  }

  @override
  Future<String?> getInstalledVersionLocally(String packageName) async {
    final result = await runCommand('pip3', ['show', '--user', packageName]);
    if (result.exitCode != 0) return null;
    return _parseVersion(result.stdout.toString());
  }

  @override
  Future<void> uninstallGlobally(String packageName) async {
    await uninstall(packageName);
  }

  @override
  Future<void> uninstallLocally(String packageName) async {
    logger.info('Uninstalling pip package locally: $packageName');
    await runCommand('pip3', ['uninstall', '-y', '--user', packageName]);
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

  String? _parseVersion(String output) {
    final versionMatch = RegExp(r'Version:\s*(.+)').firstMatch(output);
    return versionMatch?.group(1)?.trim();
  }
}
