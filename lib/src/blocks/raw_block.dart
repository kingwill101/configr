import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/shell_type.dart';
import 'package:i3config/i3config_v2.dart' as i3;

class RawBlock extends ActionBlock {
  @override
  String get blockType => 'raw';

  String command = '';
  String args = '';
  String chdir = '';
  String stdin = '';
  String executable = '/bin/sh';
  bool _executableExplicit = false;

  RawBlock();

  @override
  Map<String, String> get additionalProperties => {
    if (command.isNotEmpty) 'command': command,
    if (args.isNotEmpty) 'args': args,
    if (chdir.isNotEmpty) 'chdir': chdir,
    if (stdin.isNotEmpty) 'stdin': stdin,
    if (_executableExplicit) 'executable': executable,
  };

  @override
  void resetState() {
    super.resetState();
    command = '';
    args = '';
    chdir = '';
    stdin = '';
    executable = '/bin/sh';
    _executableExplicit = false;
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    command = (context.getVariable('command') as String?) ?? '';
    args = (context.getVariable('args') as String?) ?? '';
    chdir = (context.getVariable('chdir') as String?) ?? '';
    stdin = (context.getVariable('stdin') as String?) ?? '';
    final executableValue = context.getVariable('executable') as String?;
    if (executableValue != null) {
      executable = executableValue;
      _executableExplicit = true;
    }
  }

  @override
  String dryRunSummary() {
    if (command.isEmpty) return '$blockType: (empty)';
    return '$blockType: $command${args.isNotEmpty ? ' $args' : ''}';
  }

  @override
  Future<void> execute() async {
    if (command.isEmpty) {
      throw ActionFailedException('command is required for raw', moduleId: id);
    }

    emitEvent(
      StartedEvent(moduleId: id, message: 'Running raw command: $command'),
    );

    try {
      var fullCommand = command;
      if (args.isNotEmpty) fullCommand = '$fullCommand $args';
      if (chdir.isNotEmpty) fullCommand = 'cd $chdir && $fullCommand';

      final effectiveExecutable = _effectiveExecutable();
      final shellType = ShellType.tryParse(effectiveExecutable);
      final shellArgs =
          shellType?.scriptArgs(fullCommand) ?? ['-c', fullCommand];

      final result = await executionService.run(
        effectiveExecutable,
        shellArgs,
        runInShell: false,
        stdin: stdin.isNotEmpty ? stdin : null,
      );

      if (result.exitCode != 0) {
        throw ActionFailedException(
          'raw command failed (exit ${result.exitCode}): '
          '${result.stderr.toString().trim()}',
          moduleId: id,
        );
      }

      emitEvent(CompletedEvent(moduleId: id, message: 'Raw command completed'));
      status = 'completed';
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      throw ActionFailedException('raw failed: $e', moduleId: id);
    }
  }

  @override
  Future<void> rollback() async {}

  String _effectiveExecutable() {
    if (_executableExplicit) return executable;
    final platform = executionService.platform.toLowerCase();
    if (platform.contains('windows')) {
      return ShellType.powershell.defaultExecutable;
    }
    return executable;
  }
}
