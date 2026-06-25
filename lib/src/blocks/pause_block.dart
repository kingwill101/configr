import 'dart:async';
import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:i3config/i3config_v2.dart' as i3;

class PauseBlock extends ActionBlock {
  @override
  String get blockType => 'pause';

  int seconds = 0;
  int minutes = 0;
  String prompt = '';

  PauseBlock();

  @override
  Map<String, String> get additionalProperties => {
    if (seconds > 0) 'seconds': seconds.toString(),
    if (minutes > 0) 'minutes': minutes.toString(),
    if (prompt.isNotEmpty) 'prompt': prompt,
  };

  @override
  void resetState() {
    super.resetState();
    seconds = 0;
    minutes = 0;
    prompt = '';
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    seconds = switch (context.getVariable('seconds')) {
      final int v => v,
      final String v => int.tryParse(v) ?? 0,
      _ => 0,
    };
    minutes = switch (context.getVariable('minutes')) {
      final int v => v,
      final String v => int.tryParse(v) ?? 0,
      _ => 0,
    };
    prompt = (context.getVariable('prompt') as String?) ?? '';
  }

  @override
  String dryRunSummary() {
    final total = seconds + minutes * 60;
    if (total > 0) return '$blockType: ${total}s';
    if (prompt.isNotEmpty) return '$blockType: $prompt';
    return '$blockType: (waiting)';
  }

  @override
  Future<void> execute() async {
    final total = seconds + minutes * 60;
    if (total > 0) {
      emitEvent(StartedEvent(
        moduleId: id,
        message: 'Pausing for ${total}s',
      ));
      await Future.delayed(Duration(seconds: total));
    } else if (prompt.isNotEmpty) {
      throw ActionFailedException(
        'pause with prompt requires interactive mode',
        moduleId: id,
      );
    }
    status = 'completed';
  }

  @override
  Future<void> rollback() async {}
}
