import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:i3config/i3config_v2.dart' as i3;

class ScriptBlock extends ActionBlock {
  @override
  String get blockType => 'script';

  String script = '';
  String args = '';
  String chdir = '';
  String creates = '';
  String removes = '';

  ScriptBlock();

  @override
  Map<String, String> get additionalProperties => {
    if (script.isNotEmpty) 'script': script,
    if (args.isNotEmpty) 'args': args,
    if (chdir.isNotEmpty) 'chdir': chdir,
    if (creates.isNotEmpty) 'creates': creates,
    if (removes.isNotEmpty) 'removes': removes,
  };

  @override
  void resetState() {
    super.resetState();
    script = '';
    args = '';
    chdir = '';
    creates = '';
    removes = '';
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    script = (context.getVariable('script') as String?) ?? '';
    args = (context.getVariable('args') as String?) ?? '';
    chdir = (context.getVariable('chdir') as String?) ?? '';
    creates = (context.getVariable('creates') as String?) ?? '';
    removes = (context.getVariable('removes') as String?) ?? '';
  }

  @override
  String dryRunSummary() {
    if (script.isEmpty) return '$blockType: (empty)';
    return '$blockType: $script${args.isNotEmpty ? ' $args' : ''}';
  }

  @override
  Future<void> execute() async {
    if (script.isEmpty) {
      throw ActionFailedException('script is required', moduleId: id);
    }

    if (creates.isNotEmpty && await fileService.pathExists(creates).then((r) => r.exists)) {
      emitEvent(StatusUpdateEvent(
        moduleId: id,
        message: 'Skip script: $creates already exists',
        level: StatusEvent.info,
      ));
      status = 'completed';
      return;
    }

    if (removes.isNotEmpty && !(await fileService.pathExists(removes)).exists) {
      emitEvent(StatusUpdateEvent(
        moduleId: id,
        message: 'Skip script: $removes does not exist',
        level: StatusEvent.info,
      ));
      status = 'completed';
      return;
    }

    emitEvent(StartedEvent(
      moduleId: id,
      message: 'Running script: $script',
    ));

    try {
      final tempDir = fileSystem.systemTempDirectory;
      final tempFile = tempDir.childFile('configr_script_${DateTime.now().millisecondsSinceEpoch}');
      await fileService.copyFile(script, tempFile.path);
      await runCommand('chmod', ['+x', tempFile.path], requireElevation: true);

      final argList = args.isNotEmpty ? args.split(' ') : <String>[];
      final workingDir = chdir.isNotEmpty ? chdir : null;

      await runCommand(
        tempFile.path,
        argList,
        requireElevation: true,
        workingDirectory: workingDir,
      );

      await tempFile.delete();

      emitEvent(CompletedEvent(
        moduleId: id,
        message: 'Script $script completed',
      ));
      status = 'completed';
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      throw ActionFailedException('script failed: $e', moduleId: id);
    }
  }

  @override
  Future<void> rollback() async {}
}
