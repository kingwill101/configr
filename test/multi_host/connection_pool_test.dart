import 'dart:io';

import 'package:test/test.dart';
import 'package:configr/src/multi_host/host.dart';
import 'package:configr/src/multi_host/connection_pool.dart';
import 'package:configr/src/utils/ssh_execution_service.dart';
import 'package:configr/src/utils/execution_service.dart'
    show CommandOutputHandler;

/// A mock SSH execution service for testing.
class MockSSHExecutionService extends SSHExecutionService {
  bool _connected = false;
  bool _disconnected = false;

  @override
  bool get isConnected => _connected;
  bool get isDisconnected => _disconnected;

  @override
  Future<void> connect(Map<String, dynamic> config) async {
    _connected = true;
    _disconnected = false;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _disconnected = true;
  }

  @override
  Future<ProcessResult> run(
    String command,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
    Map<String, String>? environment,
    CommandOutputHandler? onOutput,
    String? stdin,
  }) async {
    return ProcessResult(0, 0, '', '');
  }

  @override
  Future<void> putFile(String sourcePath, String destinationPath) async {}

  @override
  Future<void> fetchFile(String sourcePath, String destinationPath) async {}
}

void main() {
  group('ConnectionPool', () {
    late ConnectionPool pool;
    final host1 = Host(name: 'web-01', address: '10.0.0.1', username: 'root');
    final host2 = Host(name: 'db-01', address: '10.0.0.2', username: 'admin');

    setUp(() {
      pool = ConnectionPool(sshFactory: () => MockSSHExecutionService());
    });

    test('acquire creates a new connection', () async {
      final ssh = await pool.acquire(host1);

      expect(ssh, isA<MockSSHExecutionService>());
      expect((ssh as MockSSHExecutionService).isConnected, isTrue);
      expect(pool.activeCount, equals(1));
    });

    test('acquire reuses existing connection for same host', () async {
      final ssh1 = await pool.acquire(host1);
      final ssh2 = await pool.acquire(host1);

      expect(identical(ssh1, ssh2), isTrue);
      expect(pool.activeCount, equals(1));
    });

    test('acquire creates separate connections for different hosts', () async {
      final ssh1 = await pool.acquire(host1);
      final ssh2 = await pool.acquire(host2);

      expect(identical(ssh1, ssh2), isFalse);
      expect(pool.activeCount, equals(2));
    });

    test('connectedHosts returns list of connected host names', () async {
      await pool.acquire(host1);
      await pool.acquire(host2);

      expect(pool.connectedHosts, containsAll(['web-01', 'db-01']));
    });

    test('release disconnects and removes the connection', () async {
      await pool.acquire(host1);
      await pool.release('web-01');

      expect(pool.activeCount, equals(0));
      expect(pool.connectedHosts, isEmpty);
    });

    test('release is safe when host not connected', () async {
      await pool.release('nonexistent');
      expect(pool.activeCount, equals(0));
    });

    test('release disconnects the SSH service', () async {
      final ssh = await pool.acquire(host1) as MockSSHExecutionService;
      await pool.release('web-01');

      expect(ssh.isDisconnected, isTrue);
    });

    test('releaseAll disconnects all connections', () async {
      await pool.acquire(host1);
      await pool.acquire(host2);

      await pool.releaseAll();

      expect(pool.activeCount, equals(0));
      expect(pool.connectedHosts, isEmpty);
    });

    test('acquire with maxConnections throws when limit reached', () async {
      pool = ConnectionPool(
        sshFactory: () => MockSSHExecutionService(),
        maxConnections: 1,
      );

      await pool.acquire(host1);

      expect(() => pool.acquire(host2), throwsA(isA<StateError>()));
    });

    test('acquire with maxConnections reuses existing', () async {
      pool = ConnectionPool(
        sshFactory: () => MockSSHExecutionService(),
        maxConnections: 2,
      );

      await pool.acquire(host1);
      await pool.acquire(host2);

      // Reusing existing connections should not hit the limit
      final ssh = await pool.acquire(host1);
      expect(ssh, isA<MockSSHExecutionService>());
    });

    test('starts with zero active connections', () {
      expect(pool.activeCount, equals(0));
      expect(pool.connectedHosts, isEmpty);
    });
  });
}
