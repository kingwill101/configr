import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/system_operations.dart';
import 'package:crypto/crypto.dart';
import 'package:file/file.dart';
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
      // Use fileSystem (package:file) which delegates to whatever FS is registered
      // in DI — local, memory, or remote (e.g. SFTP).
      // Detect symlinks via link().existsSync() (package:file has no isLinkSync)
      final linkExists = fileSystem.link(path).existsSync();
      final rawStat = fileSystem.statSync(path);
      final exists =
          linkExists || rawStat.type != FileSystemEntityType.notFound;

      context.setVariable('stat_exists', exists.toString());

      if (!exists) {
        emitEvent(
          CompletedEvent(moduleId: id, message: 'Path does not exist: $path'),
        );
        status = 'completed';
        return;
      }

      final isDir = linkExists
          ? false
          : rawStat.type == FileSystemEntityType.directory;
      final isReg = linkExists
          ? false
          : rawStat.type == FileSystemEntityType.file;

      context.setVariable('stat_islnk', linkExists.toString());
      context.setVariable('stat_isdir', isDir.toString());
      context.setVariable('stat_isreg', isReg.toString());

      String typeStr;
      if (linkExists) {
        typeStr = 'link';
      } else {
        switch (rawStat.type) {
          case FileSystemEntityType.file:
            typeStr = 'file';
          case FileSystemEntityType.directory:
            typeStr = 'directory';
          default:
            typeStr = 'other';
        }
      }
      context.setVariable('stat_type', typeStr);

      // Re-stat following symlinks for the detailed attributes
      final targetStat = fileSystem.statSync(path);

      context.setVariable('stat_mode', targetStat.mode.toRadixString(8));
      context.setVariable('stat_size', targetStat.size.toString());
      context.setVariable(
        'stat_mtime',
        targetStat.modified.toUtc().toIso8601String(),
      );
      context.setVariable(
        'stat_atime',
        targetStat.accessed.toUtc().toIso8601String(),
      );
      context.setVariable(
        'stat_ctime',
        targetStat.changed.toUtc().toIso8601String(),
      );

      // Get uid/gid via runCommand (FileStat does not expose these)
      final ops = SystemOperations(executionService.platform);
      try {
        final (uidCmd, uidArgs) = ops.uid(path);
        final uidResult = await runCommand(
          uidCmd,
          uidArgs,
          checkExitCode: false,
        );
        if (uidResult.exitCode == 0) {
          context.setVariable('stat_uid', (uidResult.stdout as String).trim());
        }
        final (gidCmd, gidArgs) = ops.gid(path);
        final gidResult = await runCommand(
          gidCmd,
          gidArgs,
          checkExitCode: false,
        );
        if (gidResult.exitCode == 0) {
          context.setVariable('stat_gid', (gidResult.stdout as String).trim());
        }
      } catch (_) {}

      // Compute checksum for regular files (not directories)
      if (isReg || (linkExists && follow)) {
        try {
          final targetPath = linkExists
              ? (await fileService.readSymlink(path)) ?? path
              : path;
          if (!await fileService.directoryExists(targetPath)) {
            final bytes = await fileService.readBinaryFile(targetPath);
            final hash = _hashForAlgorithm(checksumAlgorithm);
            context.setVariable(
              'stat_checksum',
              hash.convert(bytes).toString(),
            );
          }
        } catch (_) {}
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
