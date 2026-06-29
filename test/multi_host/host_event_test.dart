import 'package:test/test.dart';
import 'package:configr/src/multi_host/host_event.dart';

void main() {
  group('HostStartedEvent', () {
    test('creates with host name and message', () {
      final event = HostStartedEvent(
        moduleId: 'web-01',
        message: 'Starting execution',
      );

      expect(event.hostName, equals('web-01'));
      expect(event.hostStatus, equals(HostStatus.running));
      expect(event.moduleId, equals('web-01'));
      expect(event.message, equals('Starting execution'));
    });

    test('includes host data in structured output', () {
      final event = HostStartedEvent(
        moduleId: 'web-01',
        message: 'Starting execution',
      );

      final data = event.toStructuredData();
      expect(data['hostName'], equals('web-01'));
      expect(data['hostStatus'], equals('running'));
    });
  });

  group('HostCompletedEvent', () {
    test('creates with host name and message', () {
      final event = HostCompletedEvent(
        moduleId: 'web-01',
        message: 'Execution completed',
      );

      expect(event.hostName, equals('web-01'));
      expect(event.hostStatus, equals(HostStatus.succeeded));
      expect(event.moduleId, equals('web-01'));
    });

    test('includes duration when set', () {
      final event = HostCompletedEvent(
        moduleId: 'web-01',
        message: 'Execution completed',
        duration: Duration(seconds: 5),
      );

      expect(event.duration, equals(Duration(seconds: 5)));
    });
  });

  group('HostFailedEvent', () {
    test('creates with host name and error details', () {
      final event = HostFailedEvent(
        moduleId: 'db-01',
        message: 'Connection refused',
        errorCode: 'SSH_CONNECT_FAILED',
        cause: Exception('timeout'),
      );

      expect(event.hostName, equals('db-01'));
      expect(event.hostStatus, equals(HostStatus.failed));
      expect(event.errorCode, equals('SSH_CONNECT_FAILED'));
    });
  });

  group('HostSkippedEvent', () {
    test('creates with host name and reason', () {
      final event = HostSkippedEvent(
        moduleId: 'web-02',
        reason: 'Fail-fast triggered on web-01',
      );

      expect(event.hostName, equals('web-02'));
      expect(event.hostStatus, equals(HostStatus.skipped));
      expect(event.reason, contains('Fail-fast'));
    });
  });

  group('HostStatus', () {
    test('has all expected values', () {
      expect(HostStatus.values, hasLength(5));
      expect(
        HostStatus.values,
        containsAll([
          HostStatus.pending,
          HostStatus.running,
          HostStatus.succeeded,
          HostStatus.failed,
          HostStatus.skipped,
        ]),
      );
    });
  });
}
