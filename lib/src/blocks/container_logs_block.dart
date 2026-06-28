import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:i3config/i3config_v2.dart' as i3;

class ContainerLogsBlock extends ActionBlock {
  @override
  String get blockType => 'container_logs';

  String containerName = '';
  int tail = 100;
  bool follow = false;
  bool timestamps = false;
  String capturedLogs = '';

  ContainerLogsBlock();

  @override
  void resetState() {
    super.resetState();
    containerName = '';
    tail = 100;
    follow = false;
    timestamps = false;
    capturedLogs = '';
  }

  @override
  Map<String, String> get additionalProperties => {
    if (containerName.isNotEmpty) 'container': containerName,
    if (tail != 100) 'tail': tail.toString(),
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (follow) 'follow': follow,
    if (timestamps) 'timestamps': timestamps,
  };

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    containerName = context.getString('container', containerName);
    tail = switch (context.getVariable('tail')) {
      int v => v,
      String v => int.tryParse(v) ?? tail,
      _ => tail,
    };
    follow = context.getBool('follow', follow);
    timestamps = context.getBool('timestamps', timestamps);
  }

  @override
  String dryRunSummary() =>
      '$blockType: $containerName (tail=$tail)';

  @override
  Future<void> execute() async {
    emitEvent(StartedEvent(
      moduleId: id,
      message: 'Fetching logs from container $containerName',
    ));

    final args = <String>['logs'];
    if (follow) {
      args.add('--follow');
    }
    if (timestamps) {
      args.add('--timestamps');
    }
    args.addAll(['--tail', tail.toString()]);
    args.add(containerName);

    final result = await runCommand('docker', args, checkExitCode: false);
    capturedLogs = result.stdout?.toString() ?? '';

    emitEvent(CompletedEvent(
      moduleId: id,
      message: 'Fetched logs from container $containerName',
    ));

    status = 'completed';
  }

  @override
  Future<void> rollback() async {
    // Container logs has nothing to undo.
  }
}
