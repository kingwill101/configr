import 'dart:io';

import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:crypto/crypto.dart';
import 'package:i3config/i3config_v2.dart' as i3;

class StatBlock extends ActionBlock {
  @override
  String get blockType => 'stat';

  String path = '';
  bool follow = true;
  String checksumAlgorithm = 'sha256';

  StatBlock();

  @override
  Map<String, String> get additionalProperties => {
    if (path.isNotEmpty) 'path': path,
    if (checksumAlgorithm != 'sha256') 'checksum_algorithm': checksumAlgorithm,
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (!follow) 'follow': follow,
  };

  @override
  void resetState() {
    super.resetState();
    path = '';
    follow = true;
    checksumAlgorithm = 'sha256';
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    path = (context.getVariable('path') as String?) ?? '';
    source = path;
    follow = switch (context.getVariable('follow')) {
      false || 'false' => false,
      _ => true,
    };
    checksumAlgorithm =
        (context.getVariable('checksum_algorithm') as String?) ?? 'sha256';
  }

  @override
  String dryRunSummary() {
    if (path.isEmpty) return '$blockType: (empty)';
    return '$blockType: path=$path';
  }

  Hash _hashForAlgorithm(String algorithm) {
    return switch (algorithm) {
      'md5' => md5,
      'sha1' => sha1,
      'sha512' => sha512,
      _ => sha256,
    };
  }

  @override
  Future<void> execute() async {
    emitEvent(StartedEvent(moduleId: id, message: 'Stat: $path'));

    if (path.isEmpty) {
      throw ActionFailedException('Stat block requires a path', moduleId: id);
    }

try {
      // Detect type without following symlinks so we can identify links
      final type = FileSystemEntity.typeSync(path, followLinks: false);
      final exists = type != FileSystemEntityType.notFound;

      context.setVariable('stat_exists', exists.toString());

      if (!exists) {
        emitEvent(
          CompletedEvent(moduleId: id, message: 'Path does not exist: $path'),
        );
        status = 'completed';
        return;
      }

      final isLink = type == FileSystemEntityType.link;
      final isDir = type == FileSystemEntityType.directory;
      final isReg = type == FileSystemEntityType.file;

      context.setVariable('stat_islnk', isLink.toString());
      context.setVariable('stat_isdir', isDir.toString());
      context.setVariable('stat_isreg', isReg.toString());

      String typeStr;
      switch (type) {
        case FileSystemEntityType.file:
          typeStr = 'file';
        case FileSystemEntityType.directory:
          typeStr = 'directory';
        case FileSystemEntityType.link:
          typeStr = 'link';
        default:
          typeStr = 'other';
      }
      context.setVariable('stat_type', typeStr);

      // FileStat.statSync follows symlinks by design
      final stat = FileStat.statSync(path);

      context.setVariable('stat_mode', stat.mode.toRadixString(8));
      context.setVariable('stat_size', stat.size.toString());
      context.setVariable(
        'stat_mtime',
        stat.modified.toUtc().toIso8601String(),
      );
      context.setVariable(
        'stat_atime',
        stat.accessed.toUtc().toIso8601String(),
      );
      context.setVariable(
        'stat_ctime',
        stat.changed.toUtc().toIso8601String(),
      );

      // Get uid/gid via runCommand (dart:io FileStat does not expose these)
      try {
        final uidResult = await runCommand(
          'stat',
          ['-c', '%u', path],
          checkExitCode: false,
        );
        if (uidResult.exitCode == 0) {
          context.setVariable(
            'stat_uid',
            (uidResult.stdout as String).trim(),
          );
        }
        final gidResult = await runCommand(
          'stat',
          ['-c', '%g', path],
          checkExitCode: false,
        );
        if (gidResult.exitCode == 0) {
          context.setVariable(
            'stat_gid',
            (gidResult.stdout as String).trim(),
          );
        }
      } catch (_) {
        // uid/gid unavailable on this platform
      }

      // Compute checksum for regular files (not directories)
      if (isReg || (isLink && follow)) {
        try {
          final targetPath = isLink ? Link(path).targetSync() : path;
          if (!Directory(targetPath).existsSync()) {
            final bytes = File(targetPath).readAsBytesSync();
            final hash = _hashForAlgorithm(checksumAlgorithm);
            context.setVariable(
              'stat_checksum',
              hash.convert(bytes).toString(),
            );
          }
        } catch (_) {
          // checksum failed — skip
        }
      }

      emitEvent(
        CompletedEvent(moduleId: id, message: 'Stat completed for: $path'),
      );
      status = 'completed';
    } catch (e, s) {
      if (e is ActionFailedException) rethrow;
      emitEvent(FailedEvent(moduleId: id, message: 'Stat failed: $e'));
      throw ActionFailedException(
        'Failed to stat: $path',
        moduleId: id,
        cause: e,
        stackTrace: s,
      );
    }
  }

  @override
  Future<void> rollback() async {}
}
