import 'package:configr/src/package_management/package_manger.dart';
import 'package:configr/src/utils/logging.dart';

class FlatpakPackageManager extends PackageManager
    with
        GlobalInstallCapability,
        LocalInstallCapability,
        GlobalLocalContextCapability {
  FlatpakPackageManager(super.privilegeEscalation);

  @override
  String get name => 'flatpak';

  @override
  Future<void> install(String packageName, {String? version}) async {
    logger.info('Installing flatpak: $packageName');
    final args = ['install', '--user', '--noninteractive', packageName];
    await runCommand('flatpak', args);
  }

  @override
  Future<void> installGlobally(String packageName, {String? version}) async {
    logger.info('Installing flatpak globally: $packageName');
    final args = ['install', '--system', '--noninteractive', packageName];
    await runCommand('flatpak', args);
  }

  @override
  Future<void> installLocally(String packageName, {String? version}) async {
    logger.info('Installing flatpak locally: $packageName');
    final args = ['install', '--user', '--noninteractive', packageName];
    await runCommand('flatpak', args);
  }

  @override
  Future<void> uninstall(String packageName) async {
    logger.info('Uninstalling flatpak: $packageName');
    await runCommand('flatpak', ['uninstall', '--noninteractive', packageName]);
  }

  @override
  Future<bool> isInstalled(String packageName) async {
    final result = await runCommand('flatpak', [
      'list',
      '--app',
      '--columns=application',
    ]);
    if (result.exitCode != 0) return false;
    return result.stdout
        .toString()
        .split('\n')
        .any((line) => line.trim() == packageName);
  }

  @override
  Future<String?> getInstalledVersion(String packageName) async {
    final result = await runCommand('flatpak', ['info', packageName]);
    if (result.exitCode != 0) return null;
    final versionMatch = RegExp(
      r'Version:\s*(.+)',
    ).firstMatch(result.stdout.toString());
    return versionMatch?.group(1)?.trim();
  }

  @override
  Future<bool> isInstalledGlobally(String packageName) async {
    final result = await runCommand('flatpak', [
      'list',
      '--app',
      '--columns=application',
      '--system',
    ]);
    if (result.exitCode != 0) return false;
    return result.stdout
        .toString()
        .split('\n')
        .any((line) => line.trim() == packageName);
  }

  @override
  Future<bool> isInstalledLocally(String packageName) async {
    final result = await runCommand('flatpak', [
      'list',
      '--app',
      '--columns=application',
      '--user',
    ]);
    if (result.exitCode != 0) return false;
    return result.stdout
        .toString()
        .split('\n')
        .any((line) => line.trim() == packageName);
  }

  @override
  Future<String?> getInstalledVersionGlobally(String packageName) async {
    final result = await runCommand('flatpak', [
      'info',
      '--system',
      packageName,
    ]);
    if (result.exitCode != 0) return null;
    final versionMatch = RegExp(
      r'Version:\s*(.+)',
    ).firstMatch(result.stdout.toString());
    return versionMatch?.group(1)?.trim();
  }

  @override
  Future<String?> getInstalledVersionLocally(String packageName) async {
    final result = await runCommand('flatpak', ['info', '--user', packageName]);
    if (result.exitCode != 0) return null;
    final versionMatch = RegExp(
      r'Version:\s*(.+)',
    ).firstMatch(result.stdout.toString());
    return versionMatch?.group(1)?.trim();
  }

  @override
  Future<void> uninstallGlobally(String packageName) async {
    logger.info('Uninstalling flatpak globally: $packageName');
    await runCommand('flatpak', [
      'uninstall',
      '--noninteractive',
      '--system',
      packageName,
    ]);
  }

  @override
  Future<void> uninstallLocally(String packageName) async {
    logger.info('Uninstalling flatpak locally: $packageName');
    await runCommand('flatpak', [
      'uninstall',
      '--noninteractive',
      '--user',
      packageName,
    ]);
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final result = await runCommand('flatpak', ['--version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
}
