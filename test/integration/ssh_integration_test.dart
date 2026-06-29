import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:testcontainers_compose/testcontainers_compose.dart';
import 'package:configr/src/cli/configr_command_runner.dart';
import 'package:configr/src/cli/cli_exit_exception.dart';

const composeDir = 'test/integration/docker';
const sshKeyPath = 'test/integration/docker/shared/ssh/id_ed25519';

Future<void> ensureSshKeyFixture() async {
  final result = await Process.run('bash', [
    'generate_keys.sh',
  ], workingDirectory: composeDir);
  if (result.exitCode != 0) {
    throw ProcessException(
      'bash',
      ['generate_keys.sh'],
      '${result.stdout}${result.stderr}',
      result.exitCode,
    );
  }
}

Future<void> syncSshKeyFixtureFromCompose() async {
  final key = await dockerComposeExec('shared', [
    'cat',
    '/shared/ssh/id_ed25519',
  ]);
  final pubKey = await dockerComposeExec('shared', [
    'cat',
    '/shared/ssh/id_ed25519.pub',
  ]);
  final keyFile = File(sshKeyPath);
  await keyFile.parent.create(recursive: true);
  await keyFile.writeAsString(key);
  await File('$sshKeyPath.pub').writeAsString(pubKey);
  await Process.run('chmod', ['600', sshKeyPath]);
}

Future<String> dockerComposeExec(String service, List<String> args) async {
  final result = await Process.run(
    'docker',
    ['compose', 'exec', '-T', service, 'sh', '-c', args.join(' ')],
    workingDirectory: composeDir,
    runInShell: true,
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      service,
      args,
      '${result.stdout}${result.stderr}',
      result.exitCode,
    );
  }
  return result.stdout.toString();
}

Future<String> vmExec(int vm, List<String> args) async {
  return dockerComposeExec('vm$vm', args);
}

Future<String> runConfigr(List<String> args) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final runner = ConfigrCommandRunner(
    out: (s) => out.writeln(s),
    err: (s) => err.writeln(s),
    outRaw: (s) => out.write(s),
    errRaw: (s) => err.write(s),
  );
  try {
    await runner.run(args);
  } on CliExitException catch (e) {
    throw StateError('configr failed (exit ${e.exitCode}):\n$out\n$err');
  }
  return out.toString();
}

Future<void> main() async {
  group('SSH Integration', () {
    late final DockerCompose compose;

    setUpAll(() async {
      await ensureSshKeyFixture();
      compose = DockerCompose(context: composeDir, build: true, wait: true);
      await compose.start();
      for (var i = 0; i < 180; i++) {
        final containers = compose.containers();
        final vmHealthy = containers.where((c) {
          final service = c.service;
          return service != null &&
              service.startsWith('vm') &&
              c.health == 'healthy';
        }).length;
        if (vmHealthy >= 3) {
          await syncSshKeyFixtureFromCompose();
          return;
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      throw StateError('Containers did not become healthy in time');
    });

    tearDownAll(() async {
      compose.stop();
    });

    test('can apply a config file to vm1 via SSH', () async {
      final configPath = '/tmp/configr_test_apply';
      final lockPath = '$configPath.lock.json';

      if (File(lockPath).existsSync()) {
        File(lockPath).deleteSync();
      }

      final absoluteKey = path.absolute(sshKeyPath);

      final config =
          '''
inventory {
  host "localhost" {
    address = "localhost"
    port = 2221
    user = "root"
    privateKey = "$absoluteKey"
    roles = ["web"]
  }
}

file {
  file_path = "/tmp/configr_deploy_test"
  content = "deployed by configr"
}
''';

      await File(configPath).writeAsString(config);

      final output = await runConfigr([
        'apply',
        '--config',
        configPath,
        '--v2',
        '--no-interaction',
        '--target',
        'localhost',
        '--dry-run',
      ]);

      expect(
        output.contains('localhost') ||
            output.contains('dry-run') ||
            output.contains('DRY-RUN'),
        isTrue,
        reason: 'Expected apply dry-run output, got: $output',
      );
    });

    test('can create a file on vm1 via SSH deploy', () async {
      final configPath = '/tmp/configr_real_apply';
      final lockPath = '$configPath.lock.json';

      if (File(lockPath).existsSync()) {
        File(lockPath).deleteSync();
      }

      final absoluteKey = path.absolute(sshKeyPath);

      final config =
          '''
inventory {
  host "localhost" {
    address = "localhost"
    port = 2221
    user = "root"
    privateKey = "$absoluteKey"
    roles = ["web"]
  }
}

file {
  file_path = "/tmp/configr_e2e_test"
  content = "deployed by configr e2e"
}
''';

      await File(configPath).writeAsString(config);

      await runConfigr([
        'apply',
        '--config',
        configPath,
        '--v2',
        '--no-interaction',
        '--target',
        'localhost',
      ]);

      final remoteContent = await vmExec(1, ['cat', '/tmp/configr_e2e_test']);
      expect(remoteContent.trim(), equals('deployed by configr e2e'));
    });

    test('can rollback a file on vm1 via SSH', () async {
      final configPath = '/tmp/configr_real_apply';
      final lockPath = '$configPath.lock.json';

      if (File(lockPath).existsSync()) {
        File(lockPath).deleteSync();
      }

      final absoluteKey = path.absolute(sshKeyPath);

      final config =
          '''
inventory {
  host "localhost" {
    address = "localhost"
    port = 2221
    user = "root"
    privateKey = "$absoluteKey"
    roles = ["web"]
  }
}

file {
  file_path = "/tmp/configr_e2e_test"
  content = "deployed by configr e2e"
}
''';

      await File(configPath).writeAsString(config);

      await runConfigr([
        'apply',
        '--config',
        configPath,
        '--v2',
        '--no-interaction',
        '--target',
        'localhost',
      ]);

      final rollbackOutput = await runConfigr([
        'rollback',
        '--config',
        configPath,
        '--v2',
        '--no-interaction',
        '--host',
        'localhost',
        '--ssh-port',
        '2221',
        '--ssh-key',
        absoluteKey,
      ]);

      expect(rollbackOutput.toLowerCase(), contains('rollback'));

      final afterRollback = await vmExec(1, [
        'test -f /tmp/configr_e2e_test && cat /tmp/configr_e2e_test || echo __MISSING__',
      ]);
      expect(afterRollback.trim(), equals('__MISSING__'));
    });
  });
}
