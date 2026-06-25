import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:path/path.dart' as p;
import 'package:i3config/i3config_v2.dart' as i3;

class UnarchiveBlock extends ActionBlock {
  @override
  String get blockType => 'unarchive';

  String src = '';
  String dest = '';
  bool remoteSrc = false;
  String format = 'auto';
  bool listFiles = false;
  String creates = '';
  String extraOpts = '';

  UnarchiveBlock();

  @override
  Map<String, String> get additionalProperties => {
    if (src.isNotEmpty) 'src': src,
    if (dest.isNotEmpty) 'dest': dest,
    if (remoteSrc) 'remote_src': 'true',
    if (format != 'auto') 'format': format,
    if (listFiles) 'list_files': 'true',
    if (creates.isNotEmpty) 'creates': creates,
    if (extraOpts.isNotEmpty) 'extra_opts': extraOpts,
  };

  @override
  void resetState() {
    super.resetState();
    src = '';
    dest = '';
    remoteSrc = false;
    format = 'auto';
    listFiles = false;
    creates = '';
    extraOpts = '';
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    src = (context.getVariable('src') as String?) ?? '';
    dest = (context.getVariable('dest') as String?) ?? '';
    remoteSrc = switch (context.getVariable('remote_src')) {
      true || 'true' => true,
      _ => false,
    };
    format = (context.getVariable('format') as String?) ?? 'auto';
    listFiles = switch (context.getVariable('list_files')) {
      true || 'true' => true,
      _ => false,
    };
    creates = (context.getVariable('creates') as String?) ?? '';
    extraOpts = (context.getVariable('extra_opts') as String?) ?? '';
  }

  @override
  String dryRunSummary() {
    if (src.isEmpty) return '$blockType: (empty)';
    return '$blockType: $src -> $dest';
  }

  String _detectFormat(String srcPath) {
    final lower = srcPath.toLowerCase();
    if (lower.endsWith('.tar.gz') || lower.endsWith('.tgz')) return 'gzip';
    if (lower.endsWith('.tar.bz2') || lower.endsWith('.tbz') || lower.endsWith('.tbz2')) return 'bzip2';
    if (lower.endsWith('.tar.xz') || lower.endsWith('.txz')) return 'xz';
    if (lower.endsWith('.tar')) return 'tar';
    if (lower.endsWith('.zip')) return 'zip';
    if (lower.endsWith('.gz')) return 'gunzip';
    if (lower.endsWith('.bz2')) return 'bunzip2';
    return 'tar';
  }

  @override
  Future<void> execute() async {
    if (src.isEmpty || dest.isEmpty) {
      throw ActionFailedException(
        'src and dest are required for unarchive', moduleId: id,
      );
    }

    if (creates.isNotEmpty && await fileService.pathExists(creates).then((r) => r.exists)) {
      emitEvent(StatusUpdateEvent(
        moduleId: id,
        message: 'Skip unarchive: $creates already exists',
        level: StatusEvent.info,
      ));
      status = 'completed';
      return;
    }

    emitEvent(StartedEvent(
      moduleId: id,
      message: 'Extracting $src to $dest',
    ));

    try {
      if (!await fileService.directoryExists(dest)) {
        await fileService.createDirectory(dest, recursive: true);
      }

      var archivePath = src;

      if (!remoteSrc) {
        final tempDir = fileSystem.systemTempDirectory;
        final tempFile = tempDir.childFile(
          'configr_archive_${DateTime.now().millisecondsSinceEpoch}_${p.basename(src)}',
        );
        await fileService.copyFile(src, tempFile.path);
        archivePath = tempFile.path;
      }

      final fmt = format == 'auto' ? _detectFormat(archivePath) : format;
      final extraArgs = extraOpts.isNotEmpty ? extraOpts.split(' ') : <String>[];

      switch (fmt) {
        case 'gzip':
          await runCommand('tar', [
            '-xzf', archivePath, '-C', dest, ...extraArgs,
          ], requireElevation: true);
        case 'bzip2':
          await runCommand('tar', [
            '-xjf', archivePath, '-C', dest, ...extraArgs,
          ], requireElevation: true);
        case 'xz':
          await runCommand('tar', [
            '-xJf', archivePath, '-C', dest, ...extraArgs,
          ], requireElevation: true);
        case 'tar':
          await runCommand('tar', [
            '-xf', archivePath, '-C', dest, ...extraArgs,
          ], requireElevation: true);
        case 'zip':
          await runCommand('unzip', [
            archivePath, '-d', dest, ...extraArgs,
          ], requireElevation: true);
        case 'gunzip':
          await runCommand('gunzip', [
            '-c', archivePath, ...extraArgs,
          ], requireElevation: true);
        case 'bunzip2':
          await runCommand('bunzip2', [
            '-c', archivePath, ...extraArgs,
          ], requireElevation: true);
        default:
          throw ActionFailedException(
            'Unsupported archive format: $fmt', moduleId: id,
          );
      }

      if (listFiles) {
        final listResult = await runCommand(
          fmt == 'zip' ? 'unzip' : 'tar',
          fmt == 'zip'
              ? ['-l', archivePath, ...extraArgs]
              : ['-tf', archivePath, ...extraArgs],
          requireElevation: true,
          checkExitCode: false,
        );
        context.setVariable('unarchive_files', listResult.stdout as String);
      }

      emitEvent(CompletedEvent(
        moduleId: id,
        message: 'Extracted $src to $dest',
      ));
      status = 'completed';
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      throw ActionFailedException('unarchive failed: $e', moduleId: id);
    }
  }

  @override
  Future<void> rollback() async {}
}
