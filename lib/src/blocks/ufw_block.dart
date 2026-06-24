import 'dart:io';

import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/platform.dart';
import 'package:i3config/i3config_v2.dart' as i3;

/// Manages UFW firewall rules and state.
///
/// ```i3
/// ufw {
///   rule = "allow"
///   port = "8080"
///   proto = "tcp"
///   direction = "in"
///   state = "enabled"
/// }
/// ```
abstract class UfwBlock extends ActionBlock {
  @override
  String get blockType => 'ufw';

  String rule = '';
  String port = '';
  String proto = '';
  String direction = '';
  String from = '';
  String to = '';
  String state = '';
  String interface = '';
  String log = '';

  factory UfwBlock() {
    final facts = OsFacts.detect();
    facts.requireLinux('ufw');
    return _LinuxUfwBlock();
  }

  UfwBlock._();

  @override
  Map<String, String> get additionalProperties => {
    if (rule.isNotEmpty) 'rule': rule,
    if (port.isNotEmpty) 'port': port,
    if (proto.isNotEmpty) 'proto': proto,
    if (direction.isNotEmpty) 'direction': direction,
    if (from.isNotEmpty) 'from': from,
    if (to.isNotEmpty) 'to': to,
    if (state.isNotEmpty) 'state': state,
    if (interface.isNotEmpty) 'interface': interface,
    if (log.isNotEmpty) 'log': log,
  };

  @override
  void resetState() {
    super.resetState();
    rule = '';
    port = '';
    proto = '';
    direction = '';
    from = '';
    to = '';
    state = '';
    interface = '';
    log = '';
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    rule = (context.getVariable('rule') as String?) ?? '';
    port = (context.getVariable('port') as String?) ?? '';
    proto = (context.getVariable('proto') as String?) ?? '';
    direction = (context.getVariable('direction') as String?) ?? '';
    from = (context.getVariable('from') as String?) ?? '';
    to = (context.getVariable('to') as String?) ?? '';
    state = (context.getVariable('state') as String?) ?? '';
    interface = (context.getVariable('interface') as String?) ?? '';
    log = (context.getVariable('log') as String?) ?? '';
  }

  @override
  String dryRunSummary() {
    final parts = <String>[];
    if (rule.isNotEmpty) parts.add('rule=$rule');
    if (port.isNotEmpty) parts.add('port=$port');
    if (proto.isNotEmpty) parts.add('proto=$proto');
    if (direction.isNotEmpty) parts.add('direction=$direction');
    if (from.isNotEmpty) parts.add('from=$from');
    if (to.isNotEmpty) parts.add('to=$to');
    if (state.isNotEmpty) parts.add('state=$state');
    if (interface.isNotEmpty) parts.add('interface=$interface');
    if (log.isNotEmpty) parts.add('log=$log');
    if (parts.isEmpty) return '';
    return '$blockType: ${parts.join(', ')}';
  }

  Future<ProcessResult> _runUfw(List<String> args) {
    return runCommand('ufw', args, requireElevation: true, checkExitCode: false);
  }

  /// Build the rule arguments for ufw allow/deny/reject/limit.
  ///
  /// Syntax follows: ufw [--dry-run] [rule] [direction] [log] [port] [proto]
  ///                 ufw [rule] [direction] [log] from [from] to [to] port [port] proto [proto]
  List<String> _ruleArgs() {
    final args = <String>[];
    args.add(rule);

    if (direction.isNotEmpty) args.add(direction);
    if (log.isNotEmpty) args.add(log);
    if (interface.isNotEmpty) {
      args.add('on');
      args.add(interface);
    }
    if (from.isNotEmpty || to.isNotEmpty) {
      if (from.isNotEmpty) {
        args.add('from');
        args.add(from);
      }
      if (to.isNotEmpty) {
        args.add('to');
        args.add(to);
      }
      if (port.isNotEmpty) {
        args.add('port');
        args.add(port);
      }
      if (proto.isNotEmpty) {
        args.add('proto');
        args.add(proto);
      }
    } else if (port.isNotEmpty) {
      final portProto = proto.isNotEmpty ? '$port/$proto' : port;
      args.add(portProto);
    }

    return args;
  }

  @override
  Future<void> execute();
  @override
  Future<void> rollback();
}

class _LinuxUfwBlock extends UfwBlock {
  _LinuxUfwBlock() : super._();

  String _previousState = '';
  List<String> _appliedRuleArgs = const [];

  @override
  Future<void> execute() async {
    emitEvent(
      StartedEvent(
        moduleId: id,
        message: 'Managing UFW: $dryRunSummary',
      ),
    );

    try {
      if (state.isNotEmpty) {
        await _handleState();
      }
      if (rule.isNotEmpty) {
        await _handleRule();
      }

      emitEvent(
        CompletedEvent(moduleId: id, message: 'UFW managed'),
      );
      status = 'completed';
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      throw ActionFailedException('UFW failed: $e', moduleId: id);
    }
  }

  Future<void> _handleState() async {
    switch (state) {
      case 'enabled':
        final result = await _runUfw(['--force', 'enable']);
        if (result.exitCode != 0) {
          throw ActionFailedException(
            'Failed to enable UFW: ${result.stderr}',
            moduleId: id,
          );
        }
        _previousState = 'enabled';
      case 'disabled':
        final result = await _runUfw(['disable']);
        if (result.exitCode != 0) {
          throw ActionFailedException(
            'Failed to disable UFW: ${result.stderr}',
            moduleId: id,
          );
        }
        _previousState = 'disabled';
      case 'reloaded':
        final result = await _runUfw(['reload']);
        if (result.exitCode != 0) {
          throw ActionFailedException(
            'Failed to reload UFW: ${result.stderr}',
            moduleId: id,
          );
        }
      case 'reset':
        final result = await _runUfw(['--force', 'reset']);
        if (result.exitCode != 0) {
          throw ActionFailedException(
            'Failed to reset UFW: ${result.stderr}',
            moduleId: id,
          );
        }
        _previousState = 'reset';
      case '':
        break;
      default:
        throw ActionFailedException(
          'Unknown UFW state: $state. '
          'Expected: enabled, disabled, reloaded, reset',
          moduleId: id,
        );
    }
  }

  Future<void> _handleRule() async {
    if (rule.isEmpty) return;

    final validRules = ['allow', 'deny', 'reject', 'limit'];
    if (!validRules.contains(rule)) {
      throw ActionFailedException(
        'Unknown UFW rule: $rule. Expected: ${validRules.join(', ')}',
        moduleId: id,
      );
    }

    final args = _ruleArgs();
    _appliedRuleArgs = List.unmodifiable(args);

    final result = await _runUfw(args);
    if (result.exitCode != 0) {
      throw ActionFailedException(
        'Failed to add UFW rule: ${result.stderr}',
        moduleId: id,
      );
    }
  }

  @override
  Future<void> rollback() async {
    try {
      if (_previousState == 'enabled') {
        await _runUfw(['disable']);
      } else if (_previousState == 'disabled') {
        await _runUfw(['--force', 'enable']);
      } else if (_previousState == 'reset') {
        // Cannot undo a reset — best effort only.
      }

      if (_appliedRuleArgs.isNotEmpty) {
        await _runUfw(['delete', ..._appliedRuleArgs]);
      }
    } catch (_) {}
  }
}
