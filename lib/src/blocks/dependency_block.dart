import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:i3config/i3config_v2.dart' as i3;

class DependencyBlock extends ActionBlock {
  @override
  String get blockType => 'dependency';

  String from = '';
  String to = '';
  String host = '';
  int port = 0;
  String checkType = 'network';
  int timeout = 60;
  int delay = 0;
  int interval = 5;
  String state = 'reachable';

  DependencyBlock();

  @override
  Map<String, String> get additionalProperties => {
    if (from.isNotEmpty) 'from': from,
    if (to.isNotEmpty) 'to': to,
    if (host.isNotEmpty) 'host': host,
    if (port > 0) 'port': port.toString(),
    if (checkType != 'network') 'type': checkType,
    if (timeout != 60) 'timeout': timeout.toString(),
    if (delay > 0) 'delay': delay.toString(),
    if (interval != 5) 'interval': interval.toString(),
    if (state != 'reachable') 'state': state,
  };

  @override
  Map<String, bool> get additionalBoolProperties => {};

  @override
  void resetState() {
    super.resetState();
    from = '';
    to = '';
    host = '';
    port = 0;
    checkType = 'network';
    timeout = 60;
    delay = 0;
    interval = 5;
    state = 'reachable';
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);

    from = context.getString('from', from);
    to = context.getString('to', to);
    host = context.getString('host', host);
    port = switch (context.getVariable('port')) {
      final int v => v,
      final String v => int.tryParse(v) ?? 0,
      _ => 0,
    };
    checkType = context.getString('check_type', checkType);
    if (context.getString('type') case final t when t.isNotEmpty) {
      checkType = t;
    }
    timeout = switch (context.getVariable('timeout')) {
      final int v => v,
      final String v => int.tryParse(v) ?? 60,
      _ => 60,
    };
    delay = switch (context.getVariable('delay')) {
      final int v => v,
      final String v => int.tryParse(v) ?? 0,
      _ => 0,
    };
    interval = switch (context.getVariable('interval')) {
      final int v => v,
      final String v => int.tryParse(v) ?? 5,
      _ => 5,
    };
    state = context.getString('state', state);
  }

  @override
  String dryRunSummary() {
    final target = host.isNotEmpty ? host : to;
    final fromStr = from.isNotEmpty ? ' from=$from' : '';
    return '$blockType: $checkType/$state → $target${port > 0 ? ':$port' : ''}$fromStr';
  }

  @override
  Future<void> execute() async {
    final target = host.isNotEmpty ? host : to;
    if (target.isEmpty) {
      throw ActionFailedException(
        'dependency: either "host" or "to" must be set',
        moduleId: id,
      );
    }

    if (delay > 0) {
      await Future.delayed(Duration(seconds: delay));
    }

    emitEvent(
      StatusUpdateEvent(
        moduleId: id,
        message: 'Waiting for $checkType dependency: $target',
        level: StatusEvent.info,
      ),
    );

    if (from.isNotEmpty) {
      emitEvent(
        StatusUpdateEvent(
          moduleId: id,
          message: 'From host: $from',
          level: StatusEvent.info,
        ),
      );
    }

    final deadline = DateTime.now().add(Duration(seconds: timeout));
    bool reached = false;
    String lastError = '';

    while (DateTime.now().isBefore(deadline)) {
      try {
        final result = await _check();
        if (result) {
          reached = true;
          break;
        }
        lastError = 'Check returned false';
      } catch (e) {
        lastError = '$e';
      }

      await Future.delayed(Duration(seconds: interval));
    }

    if (state == 'unreachable') {
      if (reached) {
        throw ActionFailedException(
          'dependency: $target is still reachable after ${timeout}s timeout',
          moduleId: id,
        );
      }
      emitEvent(
        StatusUpdateEvent(
          moduleId: id,
          message: 'Dependency satisfied: $target is unreachable',
          level: StatusEvent.info,
        ),
      );
    } else {
      if (!reached) {
        throw ActionFailedException(
          'dependency: $target not $state after ${timeout}s timeout'
          '${lastError.isNotEmpty ? ' — $lastError' : ''}',
          moduleId: id,
        );
      }
      emitEvent(
        StatusUpdateEvent(
          moduleId: id,
          message: 'Dependency satisfied: $target is $state',
          level: StatusEvent.info,
        ),
      );
    }

    status = 'completed';
  }

  Future<bool> _check() async {
    final target = host.isNotEmpty ? host : to;
    switch (checkType) {
      case 'ping':
        final result = await executionService.run('ping', [
          '-c',
          '1',
          '-W',
          '5',
          target,
        ]);
        return result.exitCode == 0;

      case 'port':
        if (port <= 0) {
          throw ActionFailedException(
            'dependency: port check requires "port" to be set',
            moduleId: id,
          );
        }
        return await _checkPort(target, port);

      case 'network':
        if (port > 0) {
          return await _checkPort(target, port);
        }
        final result = await executionService.run('ping', [
          '-c',
          '1',
          '-W',
          '3',
          target,
        ]);
        return result.exitCode == 0;

      default:
        throw ActionFailedException(
          'dependency: unknown check type "$checkType"',
          moduleId: id,
        );
    }
  }

  Future<bool> _checkPort(String target, int port) async {
    try {
      final result = await networkService.probeTcp(
        target,
        port,
        timeoutSeconds: 5,
      );
      return result.success;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> rollback() async {
    // Dependency checks have nothing to undo.
  }
}
