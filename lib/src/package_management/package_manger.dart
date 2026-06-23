import 'dart:io';

import 'package:configr/src/utils/privilege_escalation.dart';

abstract class PackageManager {
  String get name;
  PrivilegeEscalation privilegeEscalation;

  PackageManager(this.privilegeEscalation);

  Future<void> install(String packageName, {String? version});
  Future<void> uninstall(String packageName);
  Future<bool> isInstalled(String packageName);
  Future<String?> getInstalledVersion(String packageName);
  Future<bool> isAvailable();

  /// Update the local package cache.
  /// Default no-op — override for managers that maintain a cache (e.g. apt).
  Future<void> updateCache() async {}

  /// Add a repository source.
  /// Default no-op — override for managers that support repositories.
  Future<void> addRepository(String url) async {}

  Future<ProcessResult> runCommand(String command, List<String> args) {
    return privilegeEscalation.runWithElevatedPrivileges(command, args);
  }
}

mixin GlobalInstallCapability on PackageManager {
  Future<void> installGlobally(String packageName, {String? version});
}

mixin LocalInstallCapability on PackageManager {
  Future<void> installLocally(String packageName, {String? version});
}

mixin VersionLockCapability on PackageManager {
  Future<void> lockVersion(String packageName, String version);
}

/// Capability for package managers that support separate global/local installation contexts
mixin GlobalLocalContextCapability on PackageManager {
  /// Check if a package is installed globally
  Future<bool> isInstalledGlobally(String packageName);

  /// Check if a package is installed locally
  Future<bool> isInstalledLocally(String packageName);

  /// Get the installed version of a package globally
  Future<String?> getInstalledVersionGlobally(String packageName);

  /// Get the installed version of a package locally
  Future<String?> getInstalledVersionLocally(String packageName);

  /// Uninstall a package globally
  Future<void> uninstallGlobally(String packageName);

  /// Uninstall a package locally
  Future<void> uninstallLocally(String packageName);
}
