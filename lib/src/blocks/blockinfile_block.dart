import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:i3config/i3config_v2.dart' as i3;

class BlockInFileBlock extends ActionBlock {
  @override
  String get blockType => 'blockinfile';

  String marker = '# {mark} CONFIGR MANAGED BLOCK';
  String block = '';
  bool backup = false;
  bool create = false;
  String owner = '';
  String group = '';
  String mode = '';

  BlockInFileBlock();

  @override
  Map<String, String> get additionalProperties => {
    if (marker != '# {mark} CONFIGR MANAGED BLOCK') 'marker': marker,
    if (owner.isNotEmpty) 'owner': owner,
    if (group.isNotEmpty) 'group': group,
    if (mode.isNotEmpty) 'mode': mode,
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (backup) 'backup': backup,
    if (create) 'create': create,
  };

  @override
  void resetState() {
    super.resetState();
    marker = '# {mark} CONFIGR MANAGED BLOCK';
    block = '';
    backup = false;
    create = false;
    owner = '';
    group = '';
    mode = '';
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    if (source.isEmpty) {
      source = (context.getVariable('path') as String?) ?? '';
    }
    if (status == null || status!.isEmpty) {
      status = (context.getVariable('state') as String?) ?? 'present';
    }
    marker =
        (context.getVariable('marker') as String?) ??
        '# {mark} CONFIGR MANAGED BLOCK';
    this.block = switch (context.getVariable('block')) {
      String s => s,
      _ => this.block,
    };
    this.block = switch (context.getVariable('content')) {
      String s => s,
      _ => this.block,
    };
    backup = switch (context.getVariable('backup')) {
      true || 'true' => true,
      _ => false,
    };
    create = switch (context.getVariable('create')) {
      true || 'true' => true,
      _ => false,
    };
    owner = (context.getVariable('owner') as String?) ?? '';
    group = (context.getVariable('group') as String?) ?? '';
    mode = (context.getVariable('mode') as String?) ?? '';
  }

  @override
  String dryRunSummary() {
    final path = source.isNotEmpty ? source : destination;
    if (path.isEmpty) return '';
    final action = status ?? 'present';
    final blockPreview = block.split('\n').first.trim();
    return '$blockType: $path ($action) $blockPreview';
  }

  @override
  Future<void> execute() async {
    final filePath = source.isNotEmpty ? source : destination;
    if (filePath.isEmpty) {
      throw ActionFailedException(
        'Path is required for blockinfile',
        moduleId: id,
      );
    }

    emitEvent(
      StartedEvent(moduleId: id, message: 'Managing block in $filePath'),
    );

    try {
      final file = fileSystem.file(filePath);
      final fileExists = await file.exists();

      if (!fileExists) {
        if (!create) {
          throw ActionFailedException(
            'File not found: $filePath (set create=true to create)',
            moduleId: id,
          );
        }
        await file.create(recursive: true);
      }

      if (backup && fileExists) {
        final backupPath = '$filePath.bak';
        await file.copy(backupPath);
      }

      final content = fileExists ? await file.readAsString() : '';
      final beginMarker = marker.replaceAll('{mark}', 'BEGIN');
      final endMarker = marker.replaceAll('{mark}', 'END');
      final wrappedBlock = '$beginMarker\n$block\n$endMarker';

      final beginPattern = RegExp(
        '${RegExp.escape(beginMarker)}.*?${RegExp.escape(endMarker)}',
        dotAll: true,
      );

      if (status == 'absent') {
        final newContent = content.replaceAll(beginPattern, '');
        await file.writeAsString(newContent);
      } else {
        if (beginPattern.hasMatch(content)) {
          final newContent = content.replaceAll(beginPattern, wrappedBlock);
          await file.writeAsString(newContent);
        } else {
          final newContent = content.endsWith('\n')
              ? '$content$wrappedBlock\n'
              : '$content\n$wrappedBlock\n';
          await file.writeAsString(newContent);
        }
      }

      emitEvent(
        CompletedEvent(moduleId: id, message: 'Managed block in $filePath'),
      );
      status = 'completed';
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      throw ActionFailedException('blockinfile failed: $e', moduleId: id);
    }
  }

  @override
  Future<void> rollback() async {
    final filePath = source.isNotEmpty ? source : destination;
    if (backup) {
      final backupPath = '$filePath.bak';
      final backupFile = fileSystem.file(backupPath);
      if (await backupFile.exists()) {
        await backupFile.copy(filePath);
        await backupFile.delete();
      }
    }
  }
}
