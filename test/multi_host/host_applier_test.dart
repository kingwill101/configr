import 'dart:io';

import 'package:test/test.dart';
import 'package:configr/src/multi_host/host.dart';
import 'package:configr/src/multi_host/connection_pool.dart';
import 'package:configr/src/multi_host/host_applier.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:configr/src/utils/ssh_execution_service.dart';
import 'package:configr/src/utils/execution_service.dart'
    show CommandOutputHandler;

class FakeSSH extends SSHExecutionService {
  String? uploadedSource;
  String? uploadedDest;
  String? ranCommand;
  List<String>? ranArgs;
  int exitCode;
  bool _failConnect;

  FakeSSH({this.exitCode = 0, this._failConnect = false});

  @override
  Future<void> connect(Map<String, dynamic> config) async {
    if (_failConnect) throw Exception('Connection refused');
  }

  @override
  Future<void> disconnect() async {}

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
    ranCommand = command;
    ranArgs = arguments;
    return ProcessResult(
      0,
      exitCode,
      'stdout output',
      exitCode == 0 ? '' : 'error message',
    );
  }

  @override
  Future<void> putFile(String sourcePath, String destinationPath) async {
    uploadedSource = sourcePath;
    uploadedDest = destinationPath;
  }

  @override
  Future<void> fetchFile(String sourcePath, String destinationPath) async {}
}

void main() {
  group('applyOnHost', () {
    late ConnectionPool pool;
    late EventBus eventBus;
    final host = Host(name: 'web-01', address: '10.0.0.1');

    setUp(() {
      pool = ConnectionPool(sshFactory: () => FakeSSH());
      eventBus = EventBus();
    });

    test('uploads config and runs configr apply', () async {
      final fakeSSH = FakeSSH();
      pool = ConnectionPool(sshFactory: () => fakeSSH);

      final ctx = await applyOnHost(
        host: host,
        pool: pool,
        configPath: '/local/config',
        eventBus: eventBus,
        dryRun: false,
        failFast: false,
      );

      expect(fakeSSH.uploadedSource, equals('/local/config'));
      expect(fakeSSH.uploadedDest, '/tmp/configr_config');
      expect(fakeSSH.ranCommand, equals('configr'));
      expect(fakeSSH.ranArgs, contains('apply'));
      expect(fakeSSH.ranArgs, contains('/tmp/configr_config'));
      expect(ctx.succeeded, isTrue);
    });

    test('passes --dry-run flag when dryRun is true', () async {
      final fakeSSH = FakeSSH();
      pool = ConnectionPool(sshFactory: () => fakeSSH);

      await applyOnHost(
        host: host,
        pool: pool,
        configPath: '/local/config',
        eventBus: eventBus,
        dryRun: true,
        failFast: false,
      );

      expect(fakeSSH.ranArgs, contains('--dry-run'));
    });

    test('passes --fail-fast flag when failFast is true', () async {
      final fakeSSH = FakeSSH();
      pool = ConnectionPool(sshFactory: () => fakeSSH);

      await applyOnHost(
        host: host,
        pool: pool,
        configPath: '/local/config',
        eventBus: eventBus,
        dryRun: false,
        failFast: true,
      );

      expect(fakeSSH.ranArgs, contains('--fail-fast'));
    });

    test('marks context as failed when configr fails', () async {
      final fakeSSH = FakeSSH(exitCode: 1);
      pool = ConnectionPool(sshFactory: () => fakeSSH);

      final ctx = await applyOnHost(
        host: host,
        pool: pool,
        configPath: '/local/config',
        eventBus: eventBus,
        dryRun: false,
        failFast: false,
      );

      expect(ctx.succeeded, isFalse);
      expect(ctx.errorMessage, contains('exited with code 1'));
    });

    test('accepts custom remoteConfigPath', () async {
      final fakeSSH = FakeSSH();
      pool = ConnectionPool(sshFactory: () => fakeSSH);

      await applyOnHost(
        host: host,
        pool: pool,
        configPath: '/local/config',
        remoteConfigPath: '/opt/configr/config',
        eventBus: eventBus,
        dryRun: false,
        failFast: false,
      );

      expect(fakeSSH.ranArgs, contains('/opt/configr/config'));
    });

    test('passes extraApplyArgs to configr', () async {
      final fakeSSH = FakeSSH();
      pool = ConnectionPool(sshFactory: () => fakeSSH);

      await applyOnHost(
        host: host,
        pool: pool,
        configPath: '/local/config',
        eventBus: eventBus,
        dryRun: false,
        failFast: false,
        extraApplyArgs: ['--verbose', '--host=web-01'],
      );

      expect(fakeSSH.ranArgs, contains('--verbose'));
      expect(fakeSSH.ranArgs, contains('--host=web-01'));
    });

    test('handles connection error gracefully', () async {
      final brokenSSH = FakeSSH().._failConnect = true;
      pool = ConnectionPool(sshFactory: () => brokenSSH);

      final ctx = await applyOnHost(
        host: host,
        pool: pool,
        configPath: '/local/config',
        eventBus: eventBus,
        dryRun: false,
        failFast: false,
      );

      expect(ctx.succeeded, isFalse);
      expect(ctx.errorMessage, isNotNull);
    });
  });
}
