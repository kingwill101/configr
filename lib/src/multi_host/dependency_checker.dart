import 'dart:io';

import 'package:configr/src/multi_host/inventory.dart' show Inventory;
import 'package:configr/src/utils/logging.dart' show logger;

/// Result of a single dependency check between two hosts.
class DependencyCheckResult {
  final String fromHost;
  final String toHost;
  final String checkType;
  final bool passed;
  final String? error;

  const DependencyCheckResult({
    required this.fromHost,
    required this.toHost,
    required this.checkType,
    required this.passed,
    this.error,
  });
}

/// Resolves and checks inter-host dependencies from `dependency` blocks.
///
/// Reads `dependency` block declarations from parsed config and verifies
/// that target hosts are reachable before dispatching execution.
///
/// Currently supports:
/// - `network` — ICMP ping or TCP port check
/// - `ping` — ICMP echo
/// - `port` — TCP connect
class DependencyChecker {
  final Inventory? inventory;

  const DependencyChecker({this.inventory});

  String _resolveHost(String name) {
    if (inventory != null) {
      final host = inventory!.getHost(name);
      if (host != null) {
        return host.address;
      }
    }
    return name;
  }

  /// Check a single dependency declaration.
  Future<DependencyCheckResult> check({
    required String from,
    required String to,
    String checkType = 'network',
    int port = 0,
    int timeout = 30,
  }) async {
    final target = _resolveHost(to);
    logger.info(
      'Dependency check: from=$from → $to ($target) type=$checkType',
    );

    final deadline = DateTime.now().add(Duration(seconds: timeout));
    bool reached = false;
    String lastError = '';

    while (DateTime.now().isBefore(deadline)) {
      try {
        reached = switch (checkType) {
          'ping' => await _checkPing(target),
          'port' => await _checkPort(target, port),
          'network' => port > 0
              ? await _checkPort(target, port)
              : await _checkPing(target),
          _ => throw ArgumentError('Unknown check type: $checkType'),
        };
        if (reached) break;
        lastError = 'Check returned false';
      } catch (e) {
        lastError = '$e';
      }
      await Future.delayed(const Duration(seconds: 2));
    }

    if (reached) {
      logger.info('  ✓ Dependency satisfied: $to is reachable');
    } else {
      logger.error(
        '  ✗ Dependency failed: $to not reachable'
        '${lastError.isNotEmpty ? ' — $lastError' : ''}',
      );
    }

    return DependencyCheckResult(
      fromHost: from,
      toHost: to,
      checkType: checkType,
      passed: reached,
      error: reached ? null : 'Target $to not reachable after ${timeout}s',
    );
  }

  /// Check that all dependencies for a set of hosts are satisfied.
  Future<bool> checkAll(List<DependencySpec> dependencies) async {
    if (dependencies.isEmpty) return true;

    logger.info('Checking ${dependencies.length} inter-host dependenc(ies)...');
    var allPassed = true;

    for (final dep in dependencies) {
      final result = await check(
        from: dep.from,
        to: dep.to,
        checkType: dep.checkType,
        port: dep.port,
        timeout: dep.timeout,
      );
      if (!result.passed) {
        allPassed = false;
      }
    }

    return allPassed;
  }
}

class DependencySpec {
  final String from;
  final String to;
  final String checkType;
  final int port;
  final int timeout;

  const DependencySpec({
    required this.from,
    required this.to,
    this.checkType = 'network',
    this.port = 0,
    this.timeout = 30,
  });
}

Future<bool> _checkPing(String target) async {
  try {
    final result = await Process.run('ping', [
      '-c', '1',
      '-W', '3',
      target,
    ]);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

Future<bool> _checkPort(String target, int port) async {
  try {
    final socket = await Socket.connect(
      target,
      port,
      timeout: const Duration(seconds: 5),
    );
    await socket.close();
    return true;
  } catch (_) {
    return false;
  }
}
