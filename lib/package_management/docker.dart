import 'package:configr/package_management/package_manger.dart';
import 'package:configr/utils/logging.dart';

class DockerPackageManager extends PackageManager with GlobalInstallCapability {
  DockerPackageManager(super.privilegeEscalation);

  @override
  String get name => 'docker';

  @override
  Future<void> install(String packageName, {String? version}) async {
    List<String> command = ['pull'];
    if (version != null) {
      command.add('$packageName:$version');
    } else {
      command.add('$packageName:latest');
    }
    logger.info('Pulling Docker image: ${command.join(' ')}');
    await runCommand('docker', command);
  }

  @override
  Future<void> uninstall(String packageName) async {
    logger.info('Removing Docker image: $packageName');
    await runCommand('docker', ['rmi', packageName]);
  }

  @override
  Future<bool> isInstalled(String packageName) async {
    final result =
        await runCommand('docker', ['image', 'inspect', packageName]);
    return result.exitCode == 0;
  }

  @override
  Future<String?> getInstalledVersion(String packageName) async {
    final result = await runCommand(
        'docker', ['image', 'inspect', '--format={{.Tag}}', packageName]);

    if (result.exitCode == 0) {
      return result.stdout.toString().trim();
    }
    return null;
  }

  @override
  Future<void> installGlobally(String packageName, {String? version}) async {
    // For Docker, global installation is the same as regular installation
    await install(packageName, version: version);
  }
}
