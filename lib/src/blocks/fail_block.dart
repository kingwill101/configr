import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:i3config/i3config_v2.dart' as i3;

class FailBlock extends ActionBlock {
  @override
  String get blockType => 'fail';

  String msg = '';

  FailBlock();

  @override
  Map<String, String> get additionalProperties => {
    if (msg.isNotEmpty) 'msg': msg,
  };

  @override
  void resetState() {
    super.resetState();
    msg = '';
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    msg = (context.getVariable('msg') as String?) ?? 'Assertion failed';
  }

  @override
  String dryRunSummary() => '$blockType: $msg';

  @override
  Future<void> execute() async {
    emitEvent(StartedEvent(moduleId: id, message: 'fail'));
    throw ActionFailedException(msg, moduleId: id);
  }

  @override
  Future<void> rollback() async {}
}
