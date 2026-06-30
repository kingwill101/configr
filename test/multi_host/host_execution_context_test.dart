import 'package:test/test.dart';
import 'package:configr/src/multi_host/host.dart';
import 'package:configr/src/multi_host/host_execution_context.dart';
import 'package:configr/src/utils/event_bus.dart';

void main() {
  group('HostExecutionContext', () {
    final host = Host(name: 'web-01', address: '10.0.0.1');
    final eventBus = EventBus();

    test('creates with required fields', () {
      final ctx = HostExecutionContext(
        host: host,
        remoteConfigPath: '/tmp/config',
        eventBus: eventBus,
      );

      expect(ctx.host.name, equals('web-01'));
      expect(ctx.remoteConfigPath, equals('/tmp/config'));
      expect(ctx.eventBus, equals(eventBus));
    });

    test('defaults dryRun and failFast to false', () {
      final ctx = HostExecutionContext(
        host: host,
        remoteConfigPath: '/tmp/config',
        eventBus: eventBus,
      );

      expect(ctx.dryRun, isFalse);
      expect(ctx.failFast, isFalse);
    });

    test('defaults succeeded to true', () {
      final ctx = HostExecutionContext(
        host: host,
        remoteConfigPath: '/tmp/config',
        eventBus: eventBus,
      );

      expect(ctx.succeeded, isTrue);
    });

    test('defaults errorMessage to null', () {
      final ctx = HostExecutionContext(
        host: host,
        remoteConfigPath: '/tmp/config',
        eventBus: eventBus,
      );

      expect(ctx.errorMessage, isNull);
    });

    test('accepts custom values', () {
      final ctx = HostExecutionContext(
        host: host,
        remoteConfigPath: '/tmp/custom',
        eventBus: eventBus,
        dryRun: true,
        failFast: true,
        succeeded: false,
        errorMessage: 'test error',
      );

      expect(ctx.dryRun, isTrue);
      expect(ctx.failFast, isTrue);
      expect(ctx.succeeded, isFalse);
      expect(ctx.errorMessage, equals('test error'));
    });

    test('toString produces meaningful output', () {
      final ctx = HostExecutionContext(
        host: host,
        remoteConfigPath: '/tmp/config',
        eventBus: eventBus,
      );

      final str = ctx.toString();
      expect(str, contains('web-01'));
    });
  });
}
