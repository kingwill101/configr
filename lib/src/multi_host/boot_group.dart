import 'package:configr/src/utils/logging.dart' show logger;

/// Configuration for a boot group with health check validation.
///
/// Boot groups define the order in which hosts are deployed during a
/// serial strategy deploy. Each group can have a health check command
/// that must pass before the next group proceeds (Kamal-style barriers).
class BootGroup {
  final String name;
  final List<String> hostNames;
  final String? healthCheck;
  final int maxParallel;
  final List<String> dependsOn;

  const BootGroup({
    required this.name,
    required this.hostNames,
    this.healthCheck,
    this.maxParallel = 1,
    this.dependsOn = const [],
  });
}

/// Parsed boot configuration with group ordering and health checks.
class BootConfig {
  final List<BootGroup> groups;

  const BootConfig({this.groups = const []});

  /// Return groups sorted by dependency order (topological sort).
  List<BootGroup> orderedGroups() {
    final ordered = <BootGroup>[];
    final visited = <String>{};

    void visit(BootGroup group) {
      if (visited.contains(group.name)) return;
      visited.add(group.name);
      for (final dep in group.dependsOn) {
        final depGroup = groups.where((g) => g.name == dep).firstOrNull;
        if (depGroup != null) {
          visit(depGroup);
        }
      }
      ordered.add(group);
    }

    for (final group in groups) {
      visit(group);
    }

    return ordered;
  }

  /// Validate that all dependency references exist.
  List<String> validate() {
    final errors = <String>[];
    final groupNames = groups.map((g) => g.name).toSet();

    for (final group in groups) {
      for (final dep in group.dependsOn) {
        if (!groupNames.contains(dep)) {
          errors.add(
            'Boot group "${group.name}" depends on unknown group "$dep".',
          );
        }
      }
    }

    return errors;
  }
}

/// Run a health check command for a boot group.
///
/// Returns `true` if the health check passes (exit code 0), `false` otherwise.
/// The [runCommand] callback executes a shell command and returns the exit code.
Future<bool> runHealthCheck(
  BootGroup group,
  Future<int> Function(String command) runCommand,
) async {
  if (group.healthCheck == null || group.healthCheck!.isEmpty) {
    return true;
  }

  logger.info(
    '  [boot] Running health check for group "${group.name}": '
    '${group.healthCheck}',
  );

  try {
    final exitCode = await runCommand(group.healthCheck!);
    if (exitCode == 0) {
      logger.info('  [boot] Health check passed for group "${group.name}".');
      return true;
    } else {
      logger.error(
        '  [boot] Health check failed for group "${group.name}" '
        '(exit code $exitCode).',
      );
      return false;
    }
  } catch (e) {
    logger.error('  [boot] Health check error for group "${group.name}": $e');
    return false;
  }
}
