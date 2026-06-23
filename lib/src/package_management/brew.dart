import 'package:configr/src/package_management/package_manger.dart';
import 'package:configr/src/utils/logging.dart';

class BrewPackageManager extends PackageManager
    with GlobalInstallCapability {
  BrewPackageManager(super.privilegeEscalation);

  @override
  String get name => 'brew';

  @override
  Future<void> install(String packageName, {String? version}) async {
    logger.info('Installing brew package: $packageName');
    final args = ['install', packageName];
    if (version != null) {
      args.add('$packageName@$version');
    }
    await runCommand('brew', args);
  }

  @override
  Future<void> installGlobally(String packageName, {String? version}) async {
    await install(packageName, version: version);
  }

  @override
  Future<void> uninstall(String packageName) async {
    logger.info('Uninstalling brew package: $packageName');
    await runCommand('brew', ['uninstall', packageName]);
  }

  @override
  Future<bool> isInstalled(String packageName) async {
    final result = await runCommand('brew', ['list', packageName]);
    return result.exitCode == 0;
  }

  @override
  Future<String?> getInstalledVersion(String packageName) async {
    final result = await runCommand('brew', ['info', '--json', packageName]);
    if (result.exitCode != 0) return null;
    // JSON output: [{"installed":[{"version":"1.2.3"}]}]
    try {
      final json = result.stdout.toString();
      final versionMatch =
          RegExp(r'"version"\s*:\s*"([^"]+)"').firstMatch(json);
      return versionMatch?.group(1);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> addRepository(String url) async {
    logger.info('Tapping brew repository: $url');
    await runCommand('brew', ['tap', url]);
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final result = await runCommand('brew', ['--version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
}
