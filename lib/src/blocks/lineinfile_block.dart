import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:i3config/i3config_v2.dart' as i3;

class LineInFileBlock extends ActionBlock {
  @override
  String get blockType => 'lineinfile';

  String regexp = '';
  String line = '';
  String insertAfter = '';
  String insertBefore = '';
  bool backup = false;
  bool create = false;
  String owner = '';
  String group = '';
  String mode = '';

  LineInFileBlock();

  @override
  Map<String, String> get additionalProperties => {
    if (regexp.isNotEmpty) 'regexp': regexp,
    if (line.isNotEmpty) 'line': line,
    if (insertAfter.isNotEmpty) 'insert_after': insertAfter,
    if (insertBefore.isNotEmpty) 'insert_before': insertBefore,
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
    regexp = '';
    line = '';
    insertAfter = '';
    insertBefore = '';
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
    regexp = (context.getVariable('regexp') as String?) ?? '';
    line = (context.getVariable('line') as String?) ?? '';
    insertAfter = (context.getVariable('insert_after') as String?) ?? '';
    insertBefore = (context.getVariable('insert_before') as String?) ?? '';
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
    if (regexp.isNotEmpty && line.isNotEmpty) {
      return '$blockType: $path (${status ?? 'present'}) $regexp -> $line';
    }
    return '$blockType: $path';
  }

  @override
  Future<void> execute() async {
    final filePath = source.isNotEmpty ? source : destination;
    if (filePath.isEmpty) {
      throw ActionFailedException(
        'Path is required for lineinfile',
        moduleId: id,
      );
    }

    emitEvent(
      StartedEvent(moduleId: id, message: 'Editing $filePath via lineinfile'),
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

      final lines = fileExists ? await file.readAsLines() : <String>[];

      if (status == 'absent') {
        _removeLines(lines);
      } else {
        _ensureLine(lines);
      }

      await file.writeAsString('${lines.join('\n')}\n');

      emitEvent(
        CompletedEvent(
          moduleId: id,
          message: 'Edited $filePath: ${lines.length} lines',
        ),
      );
      status = 'completed';
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      throw ActionFailedException('lineinfile failed: $e', moduleId: id);
    }
  }

  void _ensureLine(List<String> lines) {
    if (regexp.isNotEmpty) {
      final pattern = RegExp(regexp);
      for (int i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) {
          lines[i] = line;
          return;
        }
      }
    }

    if (insertBefore.isNotEmpty) {
      final beforePattern = RegExp(insertBefore);
      for (int i = 0; i < lines.length; i++) {
        if (beforePattern.hasMatch(lines[i])) {
          lines.insert(i, line);
          return;
        }
      }
    }

    if (insertAfter.isNotEmpty) {
      final afterPattern = RegExp(insertAfter);
      for (int i = lines.length - 1; i >= 0; i--) {
        if (afterPattern.hasMatch(lines[i])) {
          lines.insert(i + 1, line);
          return;
        }
      }
    }

    if (regexp.isEmpty) {
      lines.add(line);
    }
  }

  void _removeLines(List<String> lines) {
    if (regexp.isEmpty) return;
    final pattern = RegExp(regexp);
    lines.removeWhere((l) => pattern.hasMatch(l));
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
