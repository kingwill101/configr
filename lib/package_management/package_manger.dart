import 'dart:io';

import 'package:configr/utils/privellage_escallation.dart';

abstract class PackageManager {
  String get name;
  PrivilegeEscalation privilegeEscalation;

  PackageManager(this.privilegeEscalation);

  Future<void> install(String packageName, {String? version});
  Future<void> uninstall(String packageName);
  Future<bool> isInstalled(String packageName);
  Future<String?> getInstalledVersion(String packageName);

  Future<ProcessResult> runCommand(String command, List<String> args) {
    return privilegeEscalation.runWithElevatedPrivileges(command, args);
  }
}

mixin GlobalInstallCapability on PackageManager {
  Future<void> installGlobally(String packageName, {String? version});
}

mixin VersionLockCapability on PackageManager {
  Future<void> lockVersion(String packageName, String version);
}
