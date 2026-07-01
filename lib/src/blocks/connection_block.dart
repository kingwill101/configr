import 'dart:async';

import 'package:configr/src/di.dart';
import 'package:configr/src/utils/execution_service.dart';
import 'package:configr/src/utils/network_service.dart';
import 'package:configr/src/utils/ssh_execution_service.dart';
import 'package:file/file.dart' show FileSystem;
import 'package:i3config/i3config_v2.dart' as i3;

class ConnectionBlock extends i3.BaseBlockHandler {
  @override
  String get blockType => 'connection';

  @override
  FutureOr<void> handle(i3.Block block, i3.Context context) {}

  @override
  FutureOr<void> afterChildrenProcessed(
    i3.Block block,
    i3.Context context,
  ) async {
    final config = <String, dynamic>{};
    for (final entry in context.variables.entries) {
      var value = entry.value;
      if (value is String) {
        if (entry.key == 'port' || entry.key == 'connect_timeout') {
          value = int.tryParse(value) ?? value;
        }
      }
      config[entry.key] = value;
    }

    final host = config['host'] as String?;
    if (host == null || host.isEmpty) {
      context.globalContext.options['_connectionError'] =
          'connection block requires a "host" property';
      return;
    }

    try {
      final ssh = SSHExecutionService();
      await ssh.connect(config);

      di.allowReassignment = true;
      di.registerSingleton<ExecutionService>(ssh);
      di.registerSingleton<FileSystem>(ssh.fileSystem);
      di.registerSingleton<NetworkService>(ExecutionNetworkService(ssh));
      di.allowReassignment = false;

      context.globalContext.options['_connectionConfig'] = config;
    } catch (e) {
      context.globalContext.options['_connectionError'] = '[connection] $e';
    }
  }
}
