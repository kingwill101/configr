import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:i3config/i3config_v2.dart' as i3;

class ContainerExecBlock extends ActionBlock {
  @override
  String get blockType => 'container_exec';

  String containerName = '';
  String command = '';
  bool interactive = false;
  String workingDir = '';
  String capturedOutput = '';

  ContainerExecBlock();

  @override
  void resetState() {
    super.resetState();
    containerName = '';
    command = '';
    interactive = false;
    workingDir = '';
    capturedOutput = '';
  }

  @override
  Map<String, String> get additionalProperties => {
    if (containerName.isNotEmpty) 'container': containerName,
    if (command.isNotEmpty) 'command': command,
    if (workingDir.isNotEmpty) 'working_dir': workingDir,
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (interactive) 'interactive': interactive,
  };

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    containerName = context.getString('container', containerName);
    command = context.getString('command', command);
    interactive = context.getBool('interactive', interactive);
    workingDir = context.getString('working_dir', workingDir);
  }

  @override
  String dryRunSummary() =>
      '$blockType: $containerName › $command';

  @override
  Future<void> execute() async {
    emitEvent(StartedEvent(
      moduleId: id,
      message: 'Executing in container $containerName: $command',
    ));

    final args = <String>['exec'];
    if (interactive) {
      args.add('-i');
    }
    if (workingDir.isNotEmpty) {
      args.addAll(['-w', workingDir]);
    }
    args.add(containerName);
    args.addAll(command.split(' '));

    final result = await runCommand('docker', args, checkExitCode: false);
    capturedOutput = result.stdout?.toString() ?? '';

    emitEvent(CompletedEvent(
      moduleId: id,
      message: 'Executed in container $containerName',
    ));

    status = 'completed';
  }

  @override
  Future<void> rollback() async {
    // Container exec has no rollback action.
  }
}
