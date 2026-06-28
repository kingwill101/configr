import 'dart:io';

import 'package:test/test.dart';

const composeDir = 'test/integration/docker';

Future<String> dockerCompose(List<String> args) async {
  final result = await Process.run('docker', ['compose', ...args],
      workingDirectory: composeDir, runInShell: true);
  if (result.exitCode != 0) {
    throw ProcessException(
      'docker compose',
      args,
      '${result.stdout}${result.stderr}',
      result.exitCode,
    );
  }
  return result.stdout.toString();
}

Future<String> deployerExec(List<String> args) async {
  final result = await Process.run(
    'docker',
    ['compose', 'exec', '-T', 'deployer', ...args],
    workingDirectory: composeDir,
    runInShell: true,
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      'deployer',
      args,
      '${result.stdout}${result.stderr}',
      result.exitCode,
    );
  }
  return result.stdout.toString();
}

Future<String> vmExec(int vm, List<String> args) async {
  final result = await Process.run(
    'docker',
    ['compose', 'exec', '-T', 'vm$vm', ...args],
    workingDirectory: composeDir,
    runInShell: true,
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      'vm$vm',
      args,
      '${result.stdout}${result.stderr}',
      result.exitCode,
    );
  }
  return result.stdout.toString();
}

Future<void> main() async {
  group('SSH Integration', () {
    setUpAll(() async {
      await dockerCompose(['up', '-d', '--build']);
      await _waitForHealthy();
      await _preWarmDeployer();
    });

    tearDownAll(() async {
      await dockerCompose(['down', '-t', '0', '--volumes']);
    });

    test('can run configr on deployer', () async {
      final output = await deployerExec([
        'configr',
        'help',
      ]);
      expect(output, contains('Available commands:'));
      expect(output, contains('apply'));
      expect(output, contains('status'));
    });

    test('configr apply help shows host flags', () async {
      final output = await deployerExec([
        'configr',
        'apply',
        '--help',
      ]);
      expect(output, contains('--target'));
      expect(output, contains('--target-role'));
      expect(output, contains('--target-group'));
      expect(output, contains('--strategy'));
      expect(output, contains('--var='));
    });

    test('can ssh from deployer to vm1', () async {
      final hostname = await deployerExec([
        'ssh',
        '-o StrictHostKeyChecking=no',
        'vm1',
        'hostname',
      ]);
      expect(hostname.trim(), isNotEmpty);
    });

    test('can ssh from deployer to vm2', () async {
      final hostname = await deployerExec([
        'ssh',
        '-o StrictHostKeyChecking=no',
        'vm2',
        'hostname',
      ]);
      expect(hostname.trim(), isNotEmpty);
    });

    test('can ssh from deployer to vm3', () async {
      final hostname = await deployerExec([
        'ssh',
        '-o StrictHostKeyChecking=no',
        'vm3',
        'hostname',
      ]);
      expect(hostname.trim(), isNotEmpty);
    });

    test('can run a shell command on vm1 from deployer', () async {
      final content = await deployerExec([
        'ssh',
        '-o StrictHostKeyChecking=no',
        'vm1',
        'cat /etc/hostname',
      ]);
      expect(content.trim(), isNotEmpty);
    });

    test('can scp a file from deployer to vm1', () async {
      await deployerExec([
        'sh',
        '-c',
        'echo "hello from deployer" > /tmp/testfile.txt',
      ]);
      await deployerExec([
        'scp',
        '-o StrictHostKeyChecking=no',
        '/tmp/testfile.txt',
        'vm1:/tmp/testfile.txt',
      ]);
      final content = await vmExec(1, ['cat', '/tmp/testfile.txt']);
      expect(content.trim(), equals('hello from deployer'));
    });

    test('can copy a file from host to vm1 via deployer', () async {
      final remoteContent = await vmExec(1, ['cat', '/etc/hostname']);
      expect(remoteContent.trim(), isNotEmpty);
    });
  });
}

Future<void> _preWarmDeployer() async {
  try {
    await deployerExec(['configr', 'help']);
  } catch (e) {
    throw StateError('Deployer binary not ready: $e');
  }
}

Future<void> _waitForHealthy() async {
  for (var i = 0; i < 180; i++) {
    final output = await dockerCompose([
      'ps',
      '--format',
      '{{.Name}}\t{{.Status}}',
    ]);

    final lines = output.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final vmHealthy = lines.where((l) => l.startsWith('configr-test-vm') && l.contains('healthy')).length;
    final deployerUp = lines.any((l) => l.startsWith('configr-test-deployer') && l.contains('Up'));

    if (vmHealthy >= 3 && deployerUp) {
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }

  throw StateError('Containers did not become healthy in time');
}
