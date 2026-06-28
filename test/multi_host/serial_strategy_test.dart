import 'package:test/test.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/multi_host/host.dart';
import 'package:configr/src/multi_host/target.dart';
import 'package:configr/src/multi_host/strategies/serial_strategy.dart';
import 'mocks.dart';

void main() {
  group('SerialStrategy', () {
    late SerialStrategy strategy;
    late MockEventBus eventBus;
    late MockExecutionRecorder recorder;

    setUp(() {
      strategy = SerialStrategy();
      eventBus = MockEventBus();
      recorder = MockExecutionRecorder();
    });

    group('name and description', () {
      test('has correct name', () {
        expect(strategy.name, equals('serial'));
      });

      test('has description', () {
        expect(strategy.description, isNotEmpty);
        expect(strategy.description, contains('priority'));
      });
    });

    group('execute', () {
      test('executes targets in priority order (lowest first)', () async {
        final targets = [
          Target(host: Host(name: 'web-01', address: '10.0.0.1'), strategy: 'serial', priority: 5),
          Target(host: Host(name: 'db-01', address: '10.0.0.2'), strategy: 'serial', priority: 1),
          Target(host: Host(name: 'cache-01', address: '10.0.0.3'), strategy: 'serial', priority: 10),
        ];

        await strategy.execute(
          targets: targets,
          executeOnHost: recorder.successCallback(),
          globalEventBus: eventBus,
          dryRun: false,
          failFast: false,
        );

        expect(recorder.executedHosts, equals(['db-01', 'web-01', 'cache-01']));
      });

      test('executes unprioritized targets last (priority 99)', () async {
        final targets = [
          Target(host: Host(name: 'web-01', address: '10.0.0.1'), strategy: 'serial', priority: 1),
          Target(host: Host(name: 'worker-01', address: '10.0.0.2'), strategy: 'serial'),
        ];

        await strategy.execute(
          targets: targets,
          executeOnHost: recorder.successCallback(),
          globalEventBus: eventBus,
          dryRun: false,
          failFast: false,
        );

        expect(recorder.executedHosts, equals(['web-01', 'worker-01']));
      });

      test('executes targets with same priority in config order', () async {
        final targets = [
          Target(host: Host(name: 'web-01', address: '10.0.0.1'), strategy: 'serial', priority: 1),
          Target(host: Host(name: 'web-02', address: '10.0.0.2'), strategy: 'serial', priority: 1),
          Target(host: Host(name: 'web-03', address: '10.0.0.3'), strategy: 'serial', priority: 1),
        ];

        await strategy.execute(
          targets: targets,
          executeOnHost: recorder.successCallback(),
          globalEventBus: eventBus,
          dryRun: false,
          failFast: false,
        );

        expect(recorder.executedHosts, equals(['web-01', 'web-02', 'web-03']));
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
          Target(host: Host(name: 'db-01', address: '10.0.0.1'), strategy: 'serial', priority: 1),
          Target(host: Host(name: 'web-01', address: '10.0.0.2'), strategy: 'serial', priority: 5),
        ];

        final callback = recorder.failOnHosts(['db-01']);

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

        expect(recorder.executedHosts, equals(['db-01']));
        expect(recorder.failedHosts, equals(['db-01']));
      });

      test('continues on failure with fail-fast disabled', () async {
        final targets = [
          Target(host: Host(name: 'db-01', address: '10.0.0.1'), strategy: 'serial', priority: 1),
          Target(host: Host(name: 'web-01', address: '10.0.0.2'), strategy: 'serial', priority: 5),
        ];

        final callback = recorder.failOnHosts(['db-01']);

        await strategy.execute(
          targets: targets,
          executeOnHost: callback,
          globalEventBus: eventBus,
          dryRun: false,
          failFast: false,
        );

        expect(recorder.executedHosts, equals(['db-01', 'web-01']));
        expect(recorder.failedHosts, equals(['db-01']));
      });

      test('stops remaining targets in group on failure without fail-fast', () async {
        final targets = [
          Target(host: Host(name: 'db-01', address: '10.0.0.1'), strategy: 'serial', priority: 1),
          Target(host: Host(name: 'db-02', address: '10.0.0.2'), strategy: 'serial', priority: 1),
          Target(host: Host(name: 'web-01', address: '10.0.0.3'), strategy: 'serial', priority: 5),
        ];

        final callback = recorder.failOnHosts(['db-01']);

        await strategy.execute(
          targets: targets,
          executeOnHost: callback,
          globalEventBus: eventBus,
          dryRun: false,
          failFast: false,
        );

        expect(recorder.executedHosts, equals(['db-01', 'web-01']));
      });

      test('emits group status events', () async {
        final targets = [
          Target(host: Host(name: 'db-01', address: '10.0.0.1'), strategy: 'serial', priority: 1),
          Target(host: Host(name: 'web-01', address: '10.0.0.2'), strategy: 'serial', priority: 5),
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
        expect(statusEvents, hasLength(3));
        expect(statusEvents[0].level, equals(StatusEvent.info));
        expect(statusEvents[0].message, contains('boot group'));
      });
    });
  });
}
