import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:i3config/i3config_v2.dart' as i3;

class AssertBlock extends ActionBlock {
  @override
  String get blockType => 'assert';

  String condition = '';
  String failMsg = '';
  String successMsg = '';

  AssertBlock();

  @override
  Map<String, String> get additionalProperties => {
    if (condition.isNotEmpty) 'condition': condition,
    if (failMsg.isNotEmpty) 'fail_msg': failMsg,
    if (successMsg.isNotEmpty) 'success_msg': successMsg,
  };

  @override
  void resetState() {
    super.resetState();
    condition = '';
    failMsg = '';
    successMsg = '';
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    condition = (context.getVariable('condition') as String?) ?? '';
    failMsg = (context.getVariable('fail_msg') as String?) ?? '';
    successMsg = (context.getVariable('success_msg') as String?) ?? '';
  }

  @override
  String dryRunSummary() {
    if (condition.isNotEmpty) {
      return '$blockType: $condition';
    }
    return super.dryRunSummary();
  }

  @override
  Future<void> execute() async {
    if (condition.isEmpty) {
      throw ActionFailedException(
        'Condition is required for assert',
        moduleId: id,
      );
    }

    emitEvent(StartedEvent(moduleId: id, message: 'Asserting: $condition'));

    final evaluated = _evaluateCondition(condition);

    if (!evaluated) {
      final msg = failMsg.isNotEmpty ? failMsg : 'Assertion failed: $condition';
      emitEvent(FailedEvent(moduleId: id, message: msg));
      throw ActionFailedException(msg, moduleId: id);
    }

    if (successMsg.isNotEmpty) {
      emitEvent(
        StatusUpdateEvent(
          moduleId: id,
          message: successMsg,
          level: StatusEvent.info,
        ),
      );
    }

    emitEvent(
      CompletedEvent(moduleId: id, message: 'Assert passed: $condition'),
    );
    status = 'completed';
  }

  bool _evaluateCondition(String condition) {
    final trimmed = condition.trim();

    bool boolVal(String s) => s == 'true';

    if (trimmed.startsWith('\$')) {
      final varName = trimmed.substring(1).trim();
      if (varName == 'os_family') {
        return false;
      }
      return true;
    }

    if (trimmed.contains('==')) {
      final parts = trimmed.split('==').map((s) => s.trim()).toList();
      return parts[0] == parts[1];
    }

    if (trimmed.contains('!=')) {
      final parts = trimmed.split('!=').map((s) => s.trim()).toList();
      return parts[0] != parts[1];
    }

    if (trimmed.startsWith('!')) {
      return !boolVal(trimmed.substring(1));
    }

    return boolVal(trimmed);
  }

  @override
  Future<void> rollback() async {
    // Assert has nothing to undo.
  }
}
