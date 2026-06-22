import 'dart:convert';

import 'package:configr/src/exceptions.dart';
import 'package:configr/src/models/v2_lockfile_data.dart';
import 'package:file/file.dart';

/// Manages the v2 lockfile that records which blocks were applied.
///
/// The lockfile lives next to the config file as `<config>.lock.json`.
/// It is written after a successful v2 apply and read during rollback
/// so we know exactly which blocks to undo, in reverse order.
class V2LockfileManager {
  final String lockfilePath;
  final FileSystem fileSystem;

  V2LockfileManager(this.lockfilePath, {required this.fileSystem});

  /// Derive a lockfile path from a config file path.
  ///
  /// e.g. `/home/user/config` → `/home/user/config.lock.json`
  static String lockPathFor(String configPath) => '$configPath.lock.json';

  /// Write the lockfile with the given [data].
  Future<void> write(V2LockfileData data) async {
    final lockfile = fileSystem.file(lockfilePath);
    final encoder = JsonEncoder.withIndent('  ');
    await lockfile.writeAsString(encoder.convert(data.toJson()));
  }

  /// Read and parse the lockfile.
  ///
  /// Throws [LockfileNotFoundException] if the lockfile does not exist.
  Future<V2LockfileData> read() async {
    final lockfile = fileSystem.file(lockfilePath);
    if (!await lockfile.exists()) {
      throw LockfileNotFoundException(
        'No rollback information available. '
        'The lockfile at $lockfilePath does not exist. '
        'This usually means no configuration has been applied yet '
        'or the lockfile was deleted.',
      );
    }
    final content = await lockfile.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    return V2LockfileData.fromJson(json);
  }

  /// Remove the lockfile (e.g. after a full clean).
  Future<void> delete() async {
    final lockfile = fileSystem.file(lockfilePath);
    if (await lockfile.exists()) {
      await lockfile.delete();
    }
  }
}
