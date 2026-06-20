import 'dart:convert';
import 'package:configr/src/models/lockfile_data.dart';
import 'package:configr/src/exceptions.dart';
import 'package:file/file.dart';

class LockfileManager {
  final String lockfilePath;
  final FileSystem fileSystem;

  LockfileManager(this.lockfilePath, {required this.fileSystem});

  Future<void> writeLockfile(LockfileData lockfileData) async {
    final lockfile = fileSystem.file(lockfilePath);
    final sink = lockfile.openWrite();
    final encoder = JsonEncoder.withIndent('  ');

    sink.writeln(encoder.convert(lockfileData.toJson()));

    await sink.close();
  }

  Future<LockfileData> readLockfile() async {
    final lockfile = fileSystem.file(lockfilePath);
    if (!await lockfile.exists()) {
      throw LockfileNotFoundException('No rollback information available. The lockfile at $lockfilePath does not exist. This usually means no configuration has been applied yet.');
    }

    final content = await lockfile.readAsString();
    final data = json.decode(content);

    return LockfileData.fromJson(data);
  }
}
