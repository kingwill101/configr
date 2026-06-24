import 'dart:async';

import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:i3config/i3config_v2.dart' as i3;

class SetFactBlock extends ActionBlock {
  @override
  String get blockType => 'set_fact';

  final Map<String, dynamic> _facts = {};

  SetFactBlock();

  @override
  Map<String, String> get additionalProperties => const {};

  @override
  Map<String, bool> get additionalBoolProperties => const {};

  @override
  void resetState() {
    super.resetState();
    _facts.clear();
  }

  @override
  void registerScopedCommands(i3.BlockHandlerRegistry registry) {
    registry.registerCommand('fact', _FactCommandHandler(this));
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    // Assignments inside set_fact block populate the facts
    for (final element in block.body) {
      if (element is i3.Assignment) {
        final values = element.values.map((v) => v.toString()).join(', ');
        context.setVariable(element.variable, values);
        _facts[element.variable] = values;
      }
    }
  }

  @override
  String dryRunSummary() {
    if (_facts.isEmpty) return '$blockType: (empty)';
    return '$blockType: ${_facts.length} fact(s)';
  }

  @override
  Future<void> execute() async {
    emitEvent(StartedEvent(moduleId: id, message: 'Setting facts'));
    emitEvent(StatusUpdateEvent(
      moduleId: id,
      message: 'Set ${_facts.length} fact(s): ${_facts.keys.join(', ')}',
      level: StatusEvent.info,
    ));
    status = 'completed';
  }

  @override
  Future<void> rollback() async {}
}

class _FactCommandHandler extends i3.BaseCommandHandler<void> {
  final SetFactBlock _block;

  _FactCommandHandler(this._block);

  @override
  String get commandName => 'fact';

  @override
  FutureOr<void> handle(i3.Command command, i3.Context context) {
    final args = command.args.map((a) => a.toString()).join(', ');
    if (args.length >= 2) {
      // Simple parsing: first comma-separated value as key, rest as value
      final parts = args.split(',');
      if (parts.length >= 2) {
        context.setVariable(parts[0].trim(), parts.sublist(1).join(',').trim());
        _block._facts[parts[0].trim()] = parts.sublist(1).join(',').trim();
      }
    }
  }
}
