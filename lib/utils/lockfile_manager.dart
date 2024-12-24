import 'dart:convert';
import 'package:configr/models/lockfile_data.dart';
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
      throw Exception('Lockfile not found');
    }

    final content = await lockfile.readAsString();
    final data = json.decode(content);

    return LockfileData.fromJson(data);
  }
}
