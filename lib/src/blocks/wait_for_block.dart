import 'dart:io';

import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:i3config/i3config_v2.dart' as i3;

class WaitForBlock extends ActionBlock {
  @override
  String get blockType => 'wait_for';

  String host = '';
  int port = 0;
  int timeout = 300;
  int delay = 0;
  bool activeConnection = false;
  bool sleep = false;
  String path = '';
  String searchRegex = '';
  bool excludeHosts = false;

  WaitForBlock();

  @override
  Map<String, String> get additionalProperties => {
    if (host.isNotEmpty) 'host': host,
    if (port > 0) 'port': port.toString(),
    if (timeout != 300) 'timeout': timeout.toString(),
    if (delay > 0) 'delay': delay.toString(),
    if (path.isNotEmpty) 'path': path,
    if (searchRegex.isNotEmpty) 'search_regex': searchRegex,
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (activeConnection) 'active_connection': activeConnection,
    if (sleep) 'sleep': sleep,
    if (excludeHosts) 'exclude_hosts': excludeHosts,
  };

  @override
  void resetState() {
    super.resetState();
    host = '';
    port = 0;
    timeout = 300;
    delay = 0;
    activeConnection = false;
    sleep = false;
    path = '';
    searchRegex = '';
    excludeHosts = false;
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    host = (context.getVariable('host') as String?) ?? '';
    port = (context.getVariable('port') as int?) ?? 0;
    timeout = (context.getVariable('timeout') as int?) ?? 300;
    delay = (context.getVariable('delay') as int?) ?? 0;
    activeConnection = switch (context.getVariable('active_connection')) {
      true || 'true' => true,
      _ => false,
    };
    sleep = switch (context.getVariable('sleep')) {
      true || 'true' => true,
      _ => false,
    };
    path = (context.getVariable('path') as String?) ?? '';
    searchRegex = (context.getVariable('search_regex') as String?) ?? '';
    excludeHosts = switch (context.getVariable('exclude_hosts')) {
      true || 'true' => true,
      _ => false,
    };
  }

  @override
  String dryRunSummary() {
    if (port > 0) {
      return '$blockType: $host:$port (timeout=$timeout)';
    }
    if (path.isNotEmpty) {
      return '$blockType: $path (timeout=$timeout)';
    }
    return '$blockType: $host (timeout=$timeout)';
  }

  @override
  Future<void> execute() async {
    emitEvent(StartedEvent(
      moduleId: id,
      message: dryRunSummary(),
    ));

    final startTime = DateTime.now();
    final deadline = startTime.add(Duration(seconds: timeout));

    if (delay > 0) {
      await Future.delayed(Duration(seconds: delay));
    }

    try {
      bool reached = false;

      while (DateTime.now().isBefore(deadline)) {
        if (port > 0) {
          reached = await _checkPort();
        } else if (path.isNotEmpty) {
          reached = await _checkPath();
        } else if (host.isNotEmpty) {
          reached = await _checkHost();
        } else {
          throw ActionFailedException(
            'Host, port, or path is required for wait_for',
            moduleId: id,
          );
        }

        if (reached) break;
        await Future.delayed(const Duration(seconds: 1));
      }

      if (!reached) {
        throw ActionFailedException(
          'Timed out waiting for $dryRunSummary',
          moduleId: id,
        );
      }

      emitEvent(CompletedEvent(
        moduleId: id,
        message: 'Condition met: $dryRunSummary',
      ));
      status = 'completed';
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      throw ActionFailedException(
        'wait_for failed: $e',
        moduleId: id,
      );
    }
  }

  Future<bool> _checkPort() async {
    try {
      final address = host.isNotEmpty ? host : 'localhost';
      final socket = await Socket.connect(
        address,
        port,
        timeout: const Duration(seconds: 2),
      );
      if (activeConnection) {
        await socket.close();
        return true;
      }
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _checkPath() async {
    if (searchRegex.isNotEmpty) {
      final file = fileSystem.file(path);
      if (!await file.exists()) return false;
      final content = await file.readAsString();
      return RegExp(searchRegex).hasMatch(content);
    }
    return await fileSystem.file(path).exists();
  }

  Future<bool> _checkHost() async {
    try {
      final result = await Process.run('ping', [
        '-c', '1',
        '-W', '2',
        host,
      ]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> rollback() async {
    // Nothing to undo
  }
}
