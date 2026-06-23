import 'dart:convert';

import 'package:configr/src/models/package_lock_data.dart';
import 'package:file/file.dart';

/// Manages the package lockfile that records installed package versions.
///
/// The lockfile lives next to the config file as `<config>.packages.json`.
/// It is written after package operations (upgrade, lock) and read during
/// status checks to compare locked vs installed versions.
class PackageLockManager {
  final String lockfilePath;
  final FileSystem fileSystem;

  PackageLockManager(this.lockfilePath, {required this.fileSystem});

  /// Derive a package lockfile path from a config file path.
  /// e.g. `/home/user/config` → `/home/user/config.packages.json`
  static String lockPathFor(String configPath) => '$configPath.packages.json';

  /// Write the package lockfile with the given [data].
  Future<void> write(PackageLockData data) async {
    final lockfile = fileSystem.file(lockfilePath);
    final encoder = JsonEncoder.withIndent('  ');
    await lockfile.writeAsString(encoder.convert(data.toJson()));
  }

  /// Read and parse the package lockfile.
  /// Returns `null` if the lockfile does not exist.
  Future<PackageLockData?> read() async {
    final lockfile = fileSystem.file(lockfilePath);
    if (!await lockfile.exists()) return null;
    final content = await lockfile.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    return PackageLockData.fromJson(json);
  }

  /// Remove the package lockfile.
  Future<void> delete() async {
    final lockfile = fileSystem.file(lockfilePath);
    if (await lockfile.exists()) {
      await lockfile.delete();
    }
  }
}
