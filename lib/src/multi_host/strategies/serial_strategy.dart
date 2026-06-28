import 'dart:async';

import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/multi_host/host.dart' show Host;
import 'package:configr/src/multi_host/strategy.dart';
import 'package:configr/src/multi_host/target.dart' show Target;
import 'package:configr/src/utils/event_bus.dart' show EventBus;

/// Serial execution strategy with boot-group ordering (Kamal-compatible).
///
/// Targets are grouped by priority (boot group). Within each group, targets
/// execute serially. Groups are processed in ascending priority order so that
/// lower-priority groups (e.g., databases) come first and higher-priority
/// groups (e.g., web servers) come later.
///
/// If no targets have explicit priorities, falls back to config order (same
/// as linear).
class SerialStrategy {
  String get name => 'serial';

  String get description =>
      'Execute targets grouped by boot priority. Within each priority group, '
      'targets run serially. Groups are ordered by ascending priority '
      '(databases before web servers).';

  Future<void> execute({
    required List<Target> targets,
    required Future<void> Function(Host) executeOnHost,
    required EventBus globalEventBus,
    required bool dryRun,
    required bool failFast,
  }) async {
    if (targets.isEmpty) return;

    final grouped = _groupByPriority(targets);
    final sortedPriorities = grouped.keys.toList()..sort();
    var hasErrors = false;

    for (final priority in sortedPriorities) {
      final group = grouped[priority]!;
      var groupAborted = false;

      globalEventBus.emit(
        StatusUpdateEvent(
          moduleId: 'SerialStrategy',
          level: StatusEvent.info,
          message:
              'Starting boot group $priority: ${group.length} target(s)',
          correlationId: globalEventBus.executionId,
        ),
      );

      for (int i = 0; i < group.length; i++) {
        if (groupAborted) break;

        final target = group[i];
        final host = target.host;

        try {
          globalEventBus.emit(
            StartedEvent(
              moduleId: host.name,
              message:
                  'Starting serial execution of target: ${target.strategy}',
              correlationId: globalEventBus.executionId,
              metadata: {
                'boot_group': priority,
                'group_index': i,
                'group_total': group.length,
              },
            ),
          );

          await executeOnHost(host);

          globalEventBus.emit(
            CompletedEvent(
              moduleId: host.name,
              message: 'Completed serial execution of target: ${target.strategy}',
              duration: Duration.zero,
              correlationId: globalEventBus.executionId,
              metadata: {
                'boot_group': priority,
                'group_index': i,
                'group_total': group.length,
              },
            ),
          );
        } catch (e) {
          hasErrors = true;
          groupAborted = true;

          globalEventBus.emit(
            FailedEvent(
              moduleId: host.name,
              message: 'Failed serial execution of target: ${target.strategy}',
              errorCode: 'TARGET_EXECUTION_FAILED',
              cause: e,
              correlationId: globalEventBus.executionId,
              metadata: {
                'boot_group': priority,
                'group_index': i,
                'group_total': group.length,
              },
            ),
          );

          if (failFast) {
            globalEventBus.emit(
              StatusUpdateEvent(
                moduleId: 'SerialStrategy',
                level: StatusEvent.error,
                message:
                    'Serial execution failed due to fail-fast. '
                    'Stopping after boot group $priority, target $i.',
                correlationId: globalEventBus.executionId,
              ),
            );
            rethrow;
          }

          globalEventBus.emit(
            StatusUpdateEvent(
              moduleId: 'SerialStrategy',
              level: StatusEvent.warning,
              message:
                  'Serial execution skipping remaining targets in boot group '
                  '$priority after failure at index $i.',
              correlationId: globalEventBus.executionId,
            ),
          );
        }
      }
    }

    if (hasErrors) {
      globalEventBus.emit(
        StatusUpdateEvent(
          moduleId: 'SerialStrategy',
          level: StatusEvent.error,
          message:
              'Serial execution completed with errors: '
              '${targets.length} target(s) across ${sortedPriorities.length} '
              'boot group(s).',
          correlationId: globalEventBus.executionId,
        ),
      );
    } else {
      globalEventBus.emit(
        StatusUpdateEvent(
          moduleId: 'SerialStrategy',
          level: StatusEvent.info,
          message:
              'Serial execution completed successfully. All ${targets.length} '
              'target(s) across ${sortedPriorities.length} boot group(s) processed.',
          correlationId: globalEventBus.executionId,
        ),
      );
    }
  }

  Map<int, List<Target>> _groupByPriority(List<Target> targets) {
    final grouped = <int, List<Target>>{};
    for (final target in targets) {
      final priority = target.priority ?? 99;
      grouped.putIfAbsent(priority, () => []).add(target);
    }
    return grouped;
  }
}
