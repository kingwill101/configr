import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:i3config/i3config_v2.dart' as i3;

/// Block handler for the `echo` config action.
///
/// Prints a message through the event system at a configurable severity level.
///
/// ```i3
/// echo {
///   message = "Hello, world!"
///   level = "info"       # info | warning | error | debug
///   color = true
/// }
/// ```
class EchoBlock extends ActionBlock {
  @override
  String get blockType => 'echo';

  String message = '';
  bool color = true;
  bool verbose = false;
  String level = 'info';

  EchoBlock();

  @override
  Map<String, String> get additionalProperties => {
    if (message.isNotEmpty) 'message': message,
    if (level != 'info') 'level': level,
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (!color) 'color': color,
    if (verbose) 'verbose': verbose,
  };

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);

    message = (context.getVariable('message') as String?) ?? message;
    color = switch (context.getVariable('color')) {
      true => true,
      'false' || false => false,
      _ => color,
    };
    verbose = switch (context.getVariable('verbose')) {
      true => true,
      'true' => true,
      _ => verbose,
    };
    level = (context.getVariable('level') as String?) ?? level;
  }

  @override
  Future<void> execute() async {
    final statusLevel = switch (level) {
      'warning' => StatusEvent.warning,
      'error' => StatusEvent.error,
      'debug' => StatusEvent.debug,
      _ => StatusEvent.info,
    };

    emitEvent(
      StatusUpdateEvent(moduleId: id, message: message, level: statusLevel),
    );

    status = 'completed';
  }

  @override
  Future<void> rollback() async {
    // Echo has nothing to undo.
  }
}
