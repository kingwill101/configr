import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:i3config/i3config_v2.dart' as i3;

class DebugBlock extends ActionBlock {
  @override
  String get blockType => 'debug';

  String msg = '';
  String varName = '';

  DebugBlock();

  @override
  Map<String, String> get additionalProperties => {
    if (msg.isNotEmpty) 'msg': msg,
    if (varName.isNotEmpty) 'var': varName,
  };

  @override
  void resetState() {
    super.resetState();
    msg = '';
    varName = '';
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    msg = (context.getVariable('msg') as String?) ?? '';
    varName = (context.getVariable('var') as String?) ?? '';
  }

  @override
  String dryRunSummary() {
    if (msg.isNotEmpty) return '$blockType: $msg';
    if (varName.isNotEmpty) return '$blockType: var=$varName';
    return '$blockType: (empty)';
  }

  @override
  Future<void> execute() async {
    emitEvent(StartedEvent(moduleId: id, message: 'debug'));
    if (msg.isNotEmpty) {
      logger.info('[debug] $msg');
    }
    if (varName.isNotEmpty) {
      final val = context.getVariable(varName);
      logger.info('[debug] $varName = $val');
    }
    status = 'completed';
  }

  @override
  Future<void> rollback() async {}
}
