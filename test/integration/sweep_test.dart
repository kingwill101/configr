import 'dart:io';

import 'package:test/test.dart';
import 'package:configr/src/cli/configr_command_runner.dart';
import 'package:configr/src/cli/cli_exit_exception.dart';

void main() {
  const testEnv = String.fromEnvironment('CONFIGR_TEST_ENV');
  if (testEnv.isEmpty) {
    test('skip: sweep requires container environment (CONFIGR_TEST_ENV)', () {},
        skip: true);
    return;
  }

  final configsDir = Directory(
    '${Directory.current.path}/test/integration/configs',
  );

  for (final entry in configsDir.listSync(followLinks: false)) {
    if (entry is! Directory) continue;
    final dirName = entry.path.split('/').last;
    if (dirName.startsWith('_')) continue;

    final dir = Directory(entry.path);
    final configFile = File('${dir.path}/config');
    final setupScript = File('${dir.path}/setup.sh');
    final verifyScript = File('${dir.path}/verify.sh');
    final cleanupScript = File('${dir.path}/cleanup.sh');
    final tagsFile = File('${dir.path}/tags');

    if (!configFile.existsSync()) continue;

    List<String> tags = [];
    if (tagsFile.existsSync()) {
      tags = tagsFile.readAsStringSync().trim().split(RegExp(r'\s+'));
    }

    if (tags.isNotEmpty && !tags.contains(testEnv)) continue;

    group(dirName, () {
      if (cleanupScript.existsSync()) {
        tearDown(() async {
          await Process.run('bash', [cleanupScript.path]);
          final lockFile = File('${configFile.path}.lock.json');
          if (lockFile.existsSync()) lockFile.deleteSync();
        });
      } else {
        tearDown(() async {
          final lockFile = File('${configFile.path}.lock.json');
          if (lockFile.existsSync()) lockFile.deleteSync();
        });
      }

      test('applies, verifies, and is idempotent', () async {
        if (setupScript.existsSync()) {
          final setupResult = await Process.run('bash', [setupScript.path]);
          expect(setupResult.exitCode, 0,
              reason:
                  'setup.sh failed: ${setupResult.stdout}\n${setupResult.stderr}');
        }

        final out = StringBuffer();
        final err = StringBuffer();
        final runner = ConfigrCommandRunner(
          out: (s) => out.write(s),
          err: (s) => err.write(s),
        );

        try {
          await runner.run([
            'apply',
            '--v2',
            '--config',
            configFile.path,
            '-n',
          ]);
        } on CliExitException catch (e) {
          fail('configr apply failed (exit ${e.exitCode}):\n$out$err');
        }

        if (verifyScript.existsSync()) {
          final verifyResult = await Process.run('bash', [verifyScript.path]);
          expect(verifyResult.exitCode, 0,
              reason:
                  'verify.sh failed:\n${verifyResult.stdout}\n${verifyResult.stderr}');
        }

        final out2 = StringBuffer();
        final err2 = StringBuffer();
        final runner2 = ConfigrCommandRunner(
          out: (s) => out2.write(s),
          err: (s) => err2.write(s),
        );

        try {
          await runner2.run([
            'apply',
            '--v2',
            '--config',
            configFile.path,
            '-n',
          ]);
        } on CliExitException catch (e) {
          fail(
              'Second apply (idempotency) failed (exit ${e.exitCode}):\n$out2$err2');
        }
      }, tags: tags.isEmpty ? null : tags,
          timeout: const Timeout(Duration(minutes: 2)));
    });
  }
}
