import 'package:test/test.dart';
import 'package:configr/src/multi_host/boot_group.dart';

void main() {
  group('BootGroup', () {
    test('creates with required fields', () {
      final group = BootGroup(name: 'web', hostNames: ['web-01', 'web-02']);

      expect(group.name, equals('web'));
      expect(group.hostNames, equals(['web-01', 'web-02']));
      expect(group.healthCheck, isNull);
      expect(group.maxParallel, equals(1));
      expect(group.dependsOn, isEmpty);
    });

    test('creates with health check', () {
      final group = BootGroup(
        name: 'web',
        hostNames: ['web-01'],
        healthCheck: 'curl -f http://localhost:8080/health',
        maxParallel: 2,
      );

      expect(group.healthCheck, equals('curl -f http://localhost:8080/health'));
      expect(group.maxParallel, equals(2));
    });
  });

  group('BootConfig', () {
    test('orderedGroups returns groups in definition order when no deps', () {
      final config = BootConfig(
        groups: [
          BootGroup(name: 'web', hostNames: ['web-01']),
          BootGroup(name: 'worker', hostNames: ['worker-01']),
        ],
      );

      final ordered = config.orderedGroups();
      expect(ordered.map((g) => g.name).toList(), equals(['web', 'worker']));
    });

    test('orderedGroups sorts by dependency order', () {
      final config = BootConfig(
        groups: [
          BootGroup(
            name: 'worker',
            hostNames: ['worker-01'],
            dependsOn: ['web'],
          ),
          BootGroup(name: 'db', hostNames: ['db-01'], dependsOn: ['web']),
          BootGroup(name: 'web', hostNames: ['web-01']),
        ],
      );

      final ordered = config.orderedGroups();
      expect(ordered.first.name, equals('web'));
      expect(
        ordered.map((g) => g.name).toList(),
        containsAllInOrder(['web', 'worker', 'db']),
      );
    });

    test('orderedGroups handles multiple levels of deps', () {
      final config = BootConfig(
        groups: [
          BootGroup(name: 'app', hostNames: ['app-01'], dependsOn: ['db']),
          BootGroup(name: 'proxy', hostNames: ['proxy-01'], dependsOn: ['app']),
          BootGroup(name: 'db', hostNames: ['db-01']),
        ],
      );

      final ordered = config.orderedGroups();
      expect(ordered.first.name, equals('db'));
      expect(
        ordered.map((g) => g.name).toList(),
        containsAllInOrder(['db', 'app', 'proxy']),
      );
    });

    test('validate returns no errors for valid config', () {
      final config = BootConfig(
        groups: [
          BootGroup(name: 'web', hostNames: ['web-01']),
          BootGroup(
            name: 'worker',
            hostNames: ['worker-01'],
            dependsOn: ['web'],
          ),
        ],
      );

      expect(config.validate(), isEmpty);
    });

    test('validate detects missing dependency references', () {
      final config = BootConfig(
        groups: [
          BootGroup(name: 'web', hostNames: ['web-01'], dependsOn: ['db']),
        ],
      );

      final errors = config.validate();
      expect(errors, hasLength(1));
      expect(errors.first, contains('db'));
    });

    test('validate does not flag self-referencing deps', () {
      final config = BootConfig(
        groups: [
          BootGroup(name: 'web', hostNames: ['web-01'], dependsOn: ['web']),
        ],
      );

      expect(config.validate(), isEmpty);
    });
  });

  group('runHealthCheck', () {
    test('returns true when no health check is set', () async {
      final group = BootGroup(name: 'web', hostNames: ['web-01']);
      final result = await runHealthCheck(group, (_) async => 0);
      expect(result, isTrue);
    });

    test('returns true when health check passes', () async {
      final group = BootGroup(
        name: 'web',
        hostNames: ['web-01'],
        healthCheck: 'curl -f http://localhost',
      );

      final result = await runHealthCheck(group, (_) async => 0);
      expect(result, isTrue);
    });

    test('returns false when health check fails', () async {
      final group = BootGroup(
        name: 'web',
        hostNames: ['web-01'],
        healthCheck: 'curl -f http://localhost',
      );

      final result = await runHealthCheck(group, (_) async => 1);
      expect(result, isFalse);
    });

    test('returns false when health check throws', () async {
      final group = BootGroup(
        name: 'web',
        hostNames: ['web-01'],
        healthCheck: 'curl -f http://localhost',
      );

      final result = await runHealthCheck(
        group,
        (_) async => throw Exception('connection refused'),
      );
      expect(result, isFalse);
    });
  });
}
