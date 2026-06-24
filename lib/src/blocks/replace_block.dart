import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:i3config/i3config_v2.dart' as i3;

class ReplaceBlock extends ActionBlock {
  @override
  String get blockType => 'replace';

  String regexp = '';
  String replace = '';
  String after = '';
  String before = '';
  bool backup = false;
  String owner = '';
  String group = '';
  String mode = '';

  ReplaceBlock();

  @override
  Map<String, String> get additionalProperties => {
    if (regexp.isNotEmpty) 'regexp': regexp,
    if (replace.isNotEmpty) 'replace': replace,
    if (after.isNotEmpty) 'after': after,
    if (before.isNotEmpty) 'before': before,
    if (owner.isNotEmpty) 'owner': owner,
    if (group.isNotEmpty) 'group': group,
    if (mode.isNotEmpty) 'mode': mode,
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (backup) 'backup': backup,
  };

  @override
  void resetState() {
    super.resetState();
    regexp = '';
    replace = '';
    after = '';
    before = '';
    backup = false;
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
    regexp = (context.getVariable('regexp') as String?) ?? '';
    replace = (context.getVariable('replace') as String?) ?? '';
    after = (context.getVariable('after') as String?) ?? '';
    before = (context.getVariable('before') as String?) ?? '';
    backup = switch (context.getVariable('backup')) {
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
    return '$blockType: $path s/$regexp/$replace/';
  }

  @override
  Future<void> execute() async {
    final filePath = source.isNotEmpty ? source : destination;
    if (filePath.isEmpty) {
      throw ActionFailedException(
        'Path is required for replace',
        moduleId: id,
      );
    }

    emitEvent(StartedEvent(
      moduleId: id,
      message: 'Replacing in $filePath',
    ));

    try {
      final file = fileSystem.file(filePath);
      if (!await file.exists()) {
        throw ActionFailedException(
          'File not found: $filePath',
          moduleId: id,
        );
      }

      if (backup) {
        final backupPath = '$filePath.bak';
        await file.copy(backupPath);
      }

      String content = await file.readAsString();

      if (after.isNotEmpty || before.isNotEmpty) {
        content = _replaceInSection(content);
      } else {
        content = content.replaceAll(RegExp(regexp, multiLine: true), replace);
      }

      await file.writeAsString(content);

      emitEvent(CompletedEvent(
        moduleId: id,
        message: 'Replaced in $filePath',
      ));
      status = 'completed';
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      throw ActionFailedException(
        'replace failed: $e',
        moduleId: id,
      );
    }
  }

  String _replaceInSection(String content) {
    final lines = content.split('\n');
    final result = <String>[];
    bool inSection = after.isEmpty;
    final afterPattern = after.isNotEmpty ? RegExp(after) : null;
    final beforePattern = before.isNotEmpty ? RegExp(before) : null;

    for (final line in lines) {
      if (afterPattern != null && afterPattern.hasMatch(line)) {
        inSection = true;
        result.add(line);
        continue;
      }
      if (beforePattern != null && beforePattern.hasMatch(line)) {
        inSection = false;
        result.add(line);
        continue;
      }
      if (inSection) {
        result.add(line.replaceAll(RegExp(regexp, multiLine: true), replace));
      } else {
        result.add(line);
      }
    }
    return result.join('\n');
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
