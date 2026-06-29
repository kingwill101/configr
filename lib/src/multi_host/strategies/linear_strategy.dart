import 'dart:async';

import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/multi_host/host.dart' show Host;
import 'package:configr/src/multi_host/strategy.dart';
import 'package:configr/src/multi_host/target.dart' show Target;
import 'package:configr/src/utils/event_bus.dart' show EventBus;

/// Linear execution strategy (Ansible-compatible default).
///
/// The LinearStrategy is the default execution strategy for multi-host operations.
/// It processes each target sequentially, waiting for all blocks on one host to
/// complete before moving to the next host.
class LinearStrategy implements ExecutionStrategy {
  @override
  String get name => 'linear';

  @override
  String get description =>
      'Execute targets sequentially, one host at a time. All blocks on a '
      'host must complete before moving to the next host.';

  @override
  Future<void> execute({
    required List<Target> targets,
    required Future<void> Function(Host) executeOnHost,
    required EventBus globalEventBus,
    required bool dryRun,
    required bool failFast,
  }) async {
    if (targets.isEmpty) {
      return;
    }

    var hasErrors = false;

    for (int i = 0; i < targets.length; i++) {
      final target = targets[i];
      final host = target.host;

      try {
        // Emit event that we're starting execution on this host
        globalEventBus.emit(
          StartedEvent(
            moduleId: host.name,
            message: 'Starting linear execution of target: ${target.strategy}',
            correlationId: globalEventBus.executionId,
            metadata: {
              'target_index': i,
              'target_total': targets.length,
              'target_strategy': target.strategy,
              'target_priority': target.priority,
              'host_roles': host.roles,
              'host_groups': host.groups,
            },
          ),
        );

        // Execute all blocks on this host
        await executeOnHost(host);

        // Emit completion event
        globalEventBus.emit(
          CompletedEvent(
            moduleId: host.name,
            message: 'Completed linear execution of target: ${target.strategy}',
            duration: Duration.zero, // TODO: track actual duration
            correlationId: globalEventBus.executionId,
            metadata: {'target_index': i, 'target_total': targets.length},
          ),
        );
      } catch (e) {
        // Record error and potentially stop execution
        hasErrors = true;

        // Emit failure event
        globalEventBus.emit(
          FailedEvent(
            moduleId: host.name,
            message: 'Failed linear execution of target: ${target.strategy}',
            errorCode: 'TARGET_EXECUTION_FAILED',
            cause: e,
            correlationId: globalEventBus.executionId,
            metadata: {
              'target_index': i,
              'target_total': targets.length,
              'target_strategy': target.strategy,
            },
          ),
        );

        // Stop if fail-fast is enabled
        if (failFast) {
          globalEventBus.emit(
            StatusUpdateEvent(
              moduleId: 'LinearStrategy',
              level: StatusEvent.error,
              message:
                  'Linear execution failed due to fail-fast. '
                  'Stopping after failed target at index $i.',
              correlationId: globalEventBus.executionId,
            ),
          );
          rethrow;
        }

        // Continue to next target if fail-fast is disabled
        globalEventBus.emit(
          StatusUpdateEvent(
            moduleId: 'LinearStrategy',
            level: StatusEvent.warning,
            message:
                'Linear execution skipped remaining targets due to failure '
                'of target at index $i (fail-fast disabled).',
            correlationId: globalEventBus.executionId,
          ),
        );
      }
    }

    // Emit summary event
    if (hasErrors) {
      globalEventBus.emit(
        StatusUpdateEvent(
          moduleId: 'LinearStrategy',
          level: StatusEvent.error,
          message:
              'Linear execution completed with ${targets.length} '
              'targets processed, $hasErrors error(s).',
          correlationId: globalEventBus.executionId,
        ),
      );
    } else {
      globalEventBus.emit(
        StatusUpdateEvent(
          moduleId: 'LinearStrategy',
          level: StatusEvent.info,
          message:
              'Linear execution completed successfully. All '
              '${targets.length} targets processed.',
          correlationId: globalEventBus.executionId,
        ),
      );
    }
  }
}
