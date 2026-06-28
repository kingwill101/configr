import 'dart:async';

import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/multi_host/host.dart' show Host;
import 'package:configr/src/multi_host/strategy.dart';
import 'package:configr/src/multi_host/target.dart' show Target;
import 'package:configr/src/utils/event_bus.dart' show EventBus;

/// Parallel execution strategy (free-for-all, Ansible-free).
///
/// All targets execute concurrently using [Future.wait]. Errors are collected
/// but do not stop other hosts unless [failFast] is true.
class ParallelStrategy {
  String get name => 'parallel';

  String get description =>
      'Execute all targets concurrently. Each host runs independently. '
      'With fail-fast enabled, the first error cancels remaining hosts.';

  Future<void> execute({
    required List<Target> targets,
    required Future<void> Function(Host) executeOnHost,
    required EventBus globalEventBus,
    required bool dryRun,
    required bool failFast,
  }) async {
    if (targets.isEmpty) return;

    final results = await Future.wait(
      targets.asMap().entries.map((entry) {
        final i = entry.key;
        final target = entry.value;
        final host = target.host;

        return _runSingleHost(
          host: host,
          target: target,
          executeOnHost: executeOnHost,
          globalEventBus: globalEventBus,
          index: i,
          total: targets.length,
        );
      }),
      eagerError: false,
    );

    final failed = results.where((r) => r != null).cast<Exception>().toList();

    if (failed.isNotEmpty) {
      globalEventBus.emit(
        StatusUpdateEvent(
          moduleId: 'ParallelStrategy',
          level: StatusEvent.error,
          message:
              'Parallel execution completed: ${targets.length} target(s), '
              '${failed.length} failed.',
          correlationId: globalEventBus.executionId,
        ),
      );

      if (failFast) {
        throw failed.first;
      }
    } else {
      globalEventBus.emit(
        StatusUpdateEvent(
          moduleId: 'ParallelStrategy',
          level: StatusEvent.info,
          message:
              'Parallel execution completed successfully. All '
              '${targets.length} target(s) processed.',
          correlationId: globalEventBus.executionId,
        ),
      );
    }
  }

  /// Run a single host and return an error if it failed, or null on success.
  Future<Exception?> _runSingleHost({
    required Host host,
    required Target target,
    required Future<void> Function(Host) executeOnHost,
    required EventBus globalEventBus,
    required int index,
    required int total,
  }) async {
    try {
      globalEventBus.emit(
        StartedEvent(
          moduleId: host.name,
          message: 'Starting parallel execution of target: ${target.strategy}',
          correlationId: globalEventBus.executionId,
          metadata: {
            'target_index': index,
            'target_total': total,
          },
        ),
      );

      await executeOnHost(host);

      globalEventBus.emit(
        CompletedEvent(
          moduleId: host.name,
          message: 'Completed parallel execution of target: ${target.strategy}',
          duration: Duration.zero,
          correlationId: globalEventBus.executionId,
          metadata: {
            'target_index': index,
            'target_total': total,
          },
        ),
      );

      return null;
    } catch (e) {
      final error = e is Exception ? e : Exception('$e');

      globalEventBus.emit(
        FailedEvent(
          moduleId: host.name,
          message: 'Failed parallel execution of target: ${target.strategy}',
          errorCode: 'TARGET_EXECUTION_FAILED',
          cause: error,
          correlationId: globalEventBus.executionId,
          metadata: {
            'target_index': index,
            'target_total': total,
          },
        ),
      );

      return error;
    }
  }
}
