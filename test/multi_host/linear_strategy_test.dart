import 'package:test/test.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/multi_host/host.dart';
import 'package:configr/src/multi_host/target.dart';
import 'package:configr/src/multi_host/strategies/linear_strategy.dart';
import 'mocks.dart';

void main() {
  group('LinearStrategy', () {
    late LinearStrategy strategy;
    late MockEventBus eventBus;
    late MockExecutionRecorder recorder;

    setUp(() {
      strategy = LinearStrategy();
      eventBus = MockEventBus();
      recorder = MockExecutionRecorder();
    });

    group('name and description', () {
      test('has correct name', () {
        expect(strategy.name, equals('linear'));
      });

      test('has description', () {
        expect(strategy.description, isNotEmpty);
        expect(strategy.description, contains('sequentially'));
      });
    });

    group('execute', () {
      test('executes all targets in order', () async {
        final targets = [
          Target(
            host: Host(name: 'web-01', address: '10.0.0.1'),
            strategy: 'linear',
          ),
          Target(
            host: Host(name: 'web-02', address: '10.0.0.2'),
            strategy: 'linear',
          ),
          Target(
            host: Host(name: 'db-01', address: '10.0.0.3'),
            strategy: 'linear',
          ),
        ];

        await strategy.execute(
          targets: targets,
          executeOnHost: recorder.successCallback(),
          globalEventBus: eventBus,
          dryRun: false,
          failFast: false,
        );

        expect(recorder.executedHosts, equals(['web-01', 'web-02', 'db-01']));
      });

      test('emits started and completed events for each host', () async {
        final targets = [
          Target(
            host: Host(name: 'web-01', address: '10.0.0.1'),
            strategy: 'linear',
          ),
        ];

        await strategy.execute(
          targets: targets,
          executeOnHost: recorder.successCallback(),
          globalEventBus: eventBus,
          dryRun: false,
          failFast: false,
        );

        await Future.delayed(Duration.zero);

        final startedEvents = eventBus.eventsOfType<StartedEvent>();
        final completedEvents = eventBus.eventsOfType<CompletedEvent>();

        expect(startedEvents, hasLength(1));
        expect(startedEvents.first.moduleId, equals('web-01'));

        expect(completedEvents, hasLength(1));
        expect(completedEvents.first.moduleId, equals('web-01'));
      });

      test('returns early for empty targets', () async {
        await strategy.execute(
          targets: [],
          executeOnHost: recorder.successCallback(),
          globalEventBus: eventBus,
          dryRun: false,
          failFast: false,
        );

        expect(recorder.executedHosts, isEmpty);
      });

      test('stops on first failure with fail-fast', () async {
        final targets = [
          Target(
            host: Host(name: 'web-01', address: '10.0.0.1'),
            strategy: 'linear',
          ),
          Target(
            host: Host(name: 'web-02', address: '10.0.0.2'),
            strategy: 'linear',
          ),
          Target(
            host: Host(name: 'db-01', address: '10.0.0.3'),
            strategy: 'linear',
          ),
        ];

        final callback = recorder.failOnHosts(['web-01']);

        await expectLater(
          strategy.execute(
            targets: targets,
            executeOnHost: callback,
            globalEventBus: eventBus,
            dryRun: false,
            failFast: true,
          ),
          throwsA(isA<Exception>()),
        );

        await Future.delayed(Duration.zero);

        expect(recorder.executedHosts, equals(['web-01']));
        expect(recorder.failedHosts, equals(['web-01']));

        final failedEvents = eventBus.eventsOfType<FailedEvent>();
        expect(failedEvents, hasLength(1));
        expect(failedEvents.first.moduleId, equals('web-01'));

        final statusEvents = eventBus.eventsOfType<StatusUpdateEvent>();
        expect(statusEvents, hasLength(1));
        expect(statusEvents.first.level, equals(StatusEvent.error));
      });

      test('continues on failure with fail-fast disabled', () async {
        final targets = [
          Target(
            host: Host(name: 'web-01', address: '10.0.0.1'),
            strategy: 'linear',
          ),
          Target(
            host: Host(name: 'web-02', address: '10.0.0.2'),
            strategy: 'linear',
          ),
          Target(
            host: Host(name: 'db-01', address: '10.0.0.3'),
            strategy: 'linear',
          ),
        ];

        final callback = recorder.failOnHosts(['web-01']);

        await strategy.execute(
          targets: targets,
          executeOnHost: callback,
          globalEventBus: eventBus,
          dryRun: false,
          failFast: false,
        );

        await Future.delayed(Duration.zero);

        expect(recorder.executedHosts, equals(['web-01', 'web-02', 'db-01']));
        expect(recorder.failedHosts, equals(['web-01']));
      });

      test('emits summary on success', () async {
        final targets = [
          Target(
            host: Host(name: 'web-01', address: '10.0.0.1'),
            strategy: 'linear',
          ),
        ];

        await strategy.execute(
          targets: targets,
          executeOnHost: recorder.successCallback(),
          globalEventBus: eventBus,
          dryRun: false,
          failFast: false,
        );

        await Future.delayed(Duration.zero);

        final statusEvents = eventBus.eventsOfType<StatusUpdateEvent>();
        expect(statusEvents, hasLength(1));
        expect(statusEvents.first.level, equals(StatusEvent.info));
        expect(statusEvents.first.message, contains('successfully'));
      });

      test('emits error summary on failure with fail-fast disabled', () async {
        final targets = [
          Target(
            host: Host(name: 'web-01', address: '10.0.0.1'),
            strategy: 'linear',
          ),
          Target(
            host: Host(name: 'web-02', address: '10.0.0.2'),
            strategy: 'linear',
          ),
        ];

        final callback = recorder.failOnHosts(['web-01']);

        await strategy.execute(
          targets: targets,
          executeOnHost: callback,
          globalEventBus: eventBus,
          dryRun: false,
          failFast: false,
        );

        await Future.delayed(Duration.zero);

        final statusEvents = eventBus.eventsOfType<StatusUpdateEvent>();
        final errorStatus = statusEvents.firstWhere(
          (e) => e.level == StatusEvent.error,
        );
        expect(errorStatus.message, contains('error(s)'));
      });
    });
  });
}
