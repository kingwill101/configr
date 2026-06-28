import 'package:test/test.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/multi_host/host.dart';
import 'package:configr/src/multi_host/target.dart';
import 'package:configr/src/multi_host/strategies/parallel_strategy.dart';
import 'mocks.dart';

void main() {
  group('ParallelStrategy', () {
    late ParallelStrategy strategy;
    late MockEventBus eventBus;
    late MockExecutionRecorder recorder;

    setUp(() {
      strategy = ParallelStrategy();
      eventBus = MockEventBus();
      recorder = MockExecutionRecorder();
    });

    group('name and description', () {
      test('has correct name', () {
        expect(strategy.name, equals('parallel'));
      });

      test('has description', () {
        expect(strategy.description, isNotEmpty);
        expect(strategy.description, contains('concurrently'));
      });
    });

    group('execute', () {
      test('executes all targets', () async {
        final targets = [
          Target(host: Host(name: 'web-01', address: '10.0.0.1'), strategy: 'parallel'),
          Target(host: Host(name: 'web-02', address: '10.0.0.2'), strategy: 'parallel'),
          Target(host: Host(name: 'db-01', address: '10.0.0.3'), strategy: 'parallel'),
        ];

        await strategy.execute(
          targets: targets,
          executeOnHost: recorder.successCallback(),
          globalEventBus: eventBus,
          dryRun: false,
          failFast: false,
        );

        expect(recorder.executedHosts, hasLength(3));
        expect(recorder.executedHosts, containsAll(['web-01', 'web-02', 'db-01']));
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

      test('completes all targets despite failures without fail-fast', () async {
        final targets = [
          Target(host: Host(name: 'web-01', address: '10.0.0.1'), strategy: 'parallel'),
          Target(host: Host(name: 'web-02', address: '10.0.0.2'), strategy: 'parallel'),
          Target(host: Host(name: 'db-01', address: '10.0.0.3'), strategy: 'parallel'),
        ];

        final callback = recorder.failOnHosts(['web-01']);

        await strategy.execute(
          targets: targets,
          executeOnHost: callback,
          globalEventBus: eventBus,
          dryRun: false,
          failFast: false,
        );

        expect(recorder.executedHosts, hasLength(3));
        expect(recorder.failedHosts, equals(['web-01']));
      });

      test('stops on first failure with fail-fast', () async {
        final targets = [
          Target(host: Host(name: 'web-01', address: '10.0.0.1'), strategy: 'parallel'),
          Target(host: Host(name: 'web-02', address: '10.0.0.2'), strategy: 'parallel'),
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

        expect(recorder.failedHosts, equals(['web-01']));
      });

      test('emits started and completed events for each host', () async {
        final targets = [
          Target(host: Host(name: 'web-01', address: '10.0.0.1'), strategy: 'parallel'),
        ];

        await strategy.execute(
          targets: targets,
          executeOnHost: recorder.successCallback(),
          globalEventBus: eventBus,
          dryRun: false,
          failFast: false,
        );

        await Future.delayed(Duration.zero);

        expect(eventBus.eventsOfType<StartedEvent>(), hasLength(1));
        expect(eventBus.eventsOfType<CompletedEvent>(), hasLength(1));
      });

      test('emits success summary', () async {
        final targets = [
          Target(host: Host(name: 'web-01', address: '10.0.0.1'), strategy: 'parallel'),
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
    });
  });
}
