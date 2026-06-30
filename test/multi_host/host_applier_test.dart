import 'dart:io';

import 'package:file/file.dart' show FileSystem;
import 'package:file/memory.dart';
import 'package:test/test.dart';
import 'package:configr/src/multi_host/host.dart';
import 'package:configr/src/multi_host/connection_pool.dart';
import 'package:configr/src/multi_host/host_applier.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:configr/src/utils/ssh_execution_service.dart';
import 'package:configr/src/utils/execution_service.dart'
    show CommandOutputHandler;

class FakeSSH extends SSHExecutionService {
  String? ranCommand;
  List<String>? ranArgs;
  final FileSystem remoteFileSystem;
  int exitCode;
  bool _failConnect;

  FakeSSH({
    this.exitCode = 0,
    this._failConnect = false,
    FileSystem? remoteFileSystem,
  }) : remoteFileSystem = remoteFileSystem ?? MemoryFileSystem.test();

  @override
  FileSystem get fileSystem => remoteFileSystem;

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
  Future<void> putFile(String sourcePath, String destinationPath) async {}

  @override
  Future<void> fetchFile(String sourcePath, String destinationPath) async {}
}

void main() {
  group('applyOnHost', () {
    late ConnectionPool pool;
    late EventBus eventBus;
    final host = Host(name: 'web-01', address: '10.0.0.1');
    late Directory tempDir;

    Future<String> writeConfig(String body) async {
      final file = File('${tempDir.path}/config');
      await file.writeAsString(body);
      return file.path;
    }

    setUp(() {
      pool = ConnectionPool(sshFactory: () => FakeSSH());
      eventBus = EventBus();
      tempDir = Directory.systemTemp.createTempSync('configr_host_apply_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('runs local apply pipeline against SSH filesystem', () async {
      final fakeSSH = FakeSSH();
      pool = ConnectionPool(sshFactory: () => fakeSSH);
      final configPath = await writeConfig('''
file {
  file_path = "/remote.txt"
  content = "from host pipeline"
}
''');

      final ctx = await applyOnHost(
        host: host,
        pool: pool,
        configPath: configPath,
        eventBus: eventBus,
        dryRun: false,
        failFast: false,
      );

      final remoteFile = fakeSSH.remoteFileSystem.file('/remote.txt');
      expect(await remoteFile.exists(), isTrue);
      expect(await remoteFile.readAsString(), equals('from host pipeline'));
      expect(fakeSSH.ranCommand, isNull);
      expect(ctx.succeeded, isTrue);
      expect(ctx.appliedBlocks, hasLength(1));
    });

    test('dry-run does not mutate SSH filesystem', () async {
      final fakeSSH = FakeSSH();
      pool = ConnectionPool(sshFactory: () => fakeSSH);
      final configPath = await writeConfig('''
file {
  file_path = "/dry-run.txt"
  content = "no write"
}
''');

      await applyOnHost(
        host: host,
        pool: pool,
        configPath: configPath,
        eventBus: eventBus,
        dryRun: true,
        failFast: false,
      );

      expect(
        await fakeSSH.remoteFileSystem.file('/dry-run.txt').exists(),
        isFalse,
      );
    });

    test('passes --fail-fast flag when failFast is true', () async {
      final fakeSSH = FakeSSH();
      pool = ConnectionPool(sshFactory: () => fakeSSH);
      final configPath = await writeConfig('''
fail {
  message = "stop"
}
file {
  file_path = "/should-not-exist.txt"
  content = "bad"
}
''');

      final ctx = await applyOnHost(
        host: host,
        pool: pool,
        configPath: configPath,
        eventBus: eventBus,
        dryRun: false,
        failFast: true,
      );

      expect(ctx.succeeded, isFalse);
      expect(
        await fakeSSH.remoteFileSystem.file('/should-not-exist.txt').exists(),
        isFalse,
      );
    });

    test('marks context as failed when local pipeline fails', () async {
      final fakeSSH = FakeSSH();
      pool = ConnectionPool(sshFactory: () => fakeSSH);
      final configPath = await writeConfig('''
fail {
  message = "expected failure"
}
''');

      final ctx = await applyOnHost(
        host: host,
        pool: pool,
        configPath: configPath,
        eventBus: eventBus,
        dryRun: false,
        failFast: false,
      );

      expect(ctx.succeeded, isFalse);
      expect(ctx.errorMessage, contains('failed'));
    });

    test('accepts custom remoteConfigPath as context metadata', () async {
      final fakeSSH = FakeSSH();
      pool = ConnectionPool(sshFactory: () => fakeSSH);
      final configPath = await writeConfig('''
file {
  file_path = "/custom-path.txt"
  content = "ok"
}
''');

      final ctx = await applyOnHost(
        host: host,
        pool: pool,
        configPath: configPath,
        remoteConfigPath: '/opt/configr/config',
        eventBus: eventBus,
        dryRun: false,
        failFast: false,
      );

      expect(ctx.remoteConfigPath, equals('/opt/configr/config'));
      expect(
        await fakeSSH.remoteFileSystem.file('/custom-path.txt').exists(),
        isTrue,
      );
    });

    test('handles connection error gracefully', () async {
      final brokenSSH = FakeSSH().._failConnect = true;
      pool = ConnectionPool(sshFactory: () => brokenSSH);
      final configPath = await writeConfig('''
file {
  file_path = "/remote.txt"
  content = "never"
}
''');

      final ctx = await applyOnHost(
        host: host,
        pool: pool,
        configPath: configPath,
        eventBus: eventBus,
        dryRun: false,
        failFast: false,
      );

      expect(ctx.succeeded, isFalse);
      expect(ctx.errorMessage, isNotNull);
    });
  });
}
