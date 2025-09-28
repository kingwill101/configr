import 'dart:io';
import 'package:configr/package_management/package_manger.dart';
import 'package:configr/utils/logging.dart';

class NpmPackageManager extends PackageManager with GlobalInstallCapability {
  NpmPackageManager(super.privilegeEscalation);

  @override
  String get name => 'npm';

  @override
  Future<void> install(String packageName, {String? version}) async {
    List<String> command = ['install'];
    if (version != null) {
      command.add('$packageName@$version');
    } else {
      command.add(packageName);
    }
    logger.info('Installing npm package: ${command.join(' ')}');
    await runCommand('npm', command);
  }

  @override
  Future<void> uninstall(String packageName) async {
    logger.info('Uninstalling npm package: $packageName');
    await runCommand('npm', ['uninstall', packageName]);
  }

  @override
  Future<bool> isInstalled(String packageName) async {
    final result = await runCommand('npm', ['list', '--depth=0', packageName]);
    return result.exitCode == 0;
  }

  @override
  Future<String?> getInstalledVersion(String packageName) async {
    final result = await runCommand('npm', ['list', '--depth=0', '--json', packageName]);
    if (result.exitCode == 0) {
      // Parse JSON output to extract version
      // This is a simplified version - in practice you'd want proper JSON parsing
      final output = result.stdout.toString();
      // Look for version in the JSON output
      final versionMatch = RegExp(r'"version":\s*"([^"]+)"').firstMatch(output);
      if (versionMatch != null) {
        return versionMatch.group(1);
      }
    }
    return null;
  }

  @override
  Future<void> installGlobally(String packageName, {String? version}) async {
    List<String> command = ['install', '-g'];
    if (version != null) {
      command.add('$packageName@$version');
    } else {
      command.add(packageName);
    }
    logger.info('Installing npm package globally: ${command.join(' ')}');
    await runCommand('npm', command);
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final result = await Process.run('npm', ['--version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
}
