import 'dart:io';

import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';

import 'package:path/path.dart' as p;
import 'package:i3config/i3config_v2.dart' as i3;

class FetchBlock extends ActionBlock {
  @override
  String get blockType => 'fetch';

  String src = '';
  String dest = '';
  bool flat = false;
  bool failOnMissing = true;

  FetchBlock();

  @override
  Map<String, String> get additionalProperties => {
    if (src.isNotEmpty) 'src': src,
    if (dest.isNotEmpty) 'dest': dest,
    if (flat) 'flat': 'true',
    if (!failOnMissing) 'fail_on_missing': 'false',
  };

  @override
  void resetState() {
    super.resetState();
    src = '';
    dest = '';
    flat = false;
    failOnMissing = true;
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    src = (context.getVariable('src') as String?) ?? '';
    dest = (context.getVariable('dest') as String?) ?? '';
    flat = switch (context.getVariable('flat')) {
      true || 'true' => true,
      _ => false,
    };
    failOnMissing = switch (context.getVariable('fail_on_missing')) {
      false || 'false' => false,
      _ => true,
    };
  }

  @override
  String dryRunSummary() {
    if (src.isEmpty) return '$blockType: (empty)';
    final target = flat ? dest : p.join(dest, _hostname, src);
    return '$blockType: $src -> $target';
  }

  String get _hostname => Platform.localHostname;

  @override
  Future<void> execute() async {
    if (src.isEmpty || dest.isEmpty) {
      throw ActionFailedException(
        'src and dest are required for fetch', moduleId: id,
      );
    }

    if (!await fileService.fileExists(src)) {
      if (failOnMissing) {
        throw ActionFailedException(
          'src file not found: $src', moduleId: id,
        );
      }
      emitEvent(StatusUpdateEvent(
        moduleId: id,
        message: 'Skip fetch: $src does not exist',
        level: StatusEvent.info,
      ));
      status = 'completed';
      return;
    }

    emitEvent(StartedEvent(
      moduleId: id,
      message: 'Fetching $src to $dest',
    ));

    try {
      final targetPath = flat
          ? (await fileService.pathExists(dest)).isDir
              ? p.join(dest, p.basename(src))
              : dest
          : p.join(dest, _hostname, src);

      final targetDir = p.dirname(targetPath);
      if (!await fileService.directoryExists(targetDir)) {
        await fileService.createDirectoryWithPermissions(targetDir, requireElevation: false);
      }

      await fileService.copyFile(src, targetPath);

      emitEvent(CompletedEvent(
        moduleId: id,
        message: 'Fetched $src to $targetPath',
      ));
      status = 'completed';
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      throw ActionFailedException('fetch failed: $e', moduleId: id);
    }
  }

  @override
  Future<void> rollback() async {}
}
