import 'dart:io';

import 'package:test/test.dart';
import 'package:configr/src/cli/configr_command_runner.dart';
import 'package:configr/src/cli/cli_exit_exception.dart';

void main() {
  final testEnv = Platform.environment['CONFIGR_TEST_ENV'] ?? '';
  final testRollback = switch (Platform.environment['CONFIGR_TEST_ROLLBACK']) {
    '1' || 'true' || 'yes' => true,
    _ => false,
  };
  if (testEnv.isEmpty) {
    test(
      'skip: sweep requires container environment (CONFIGR_TEST_ENV)',
      () {},
      skip: true,
    );
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
    final verifyRollbackScript = File('${dir.path}/verify_rollback.sh');
    final cleanupScript = File('${dir.path}/cleanup.sh');
    final tagsFile = File('${dir.path}/tags');
    final argsFile = File('${dir.path}/args');
    final outContainsFile = File('${dir.path}/out_contains');
    final outNotContainsFile = File('${dir.path}/out_not_contains');

    if (!configFile.existsSync()) continue;

    List<String> tags = [];
    if (tagsFile.existsSync()) {
      tags = tagsFile.readAsStringSync().trim().split(RegExp(r'\s+'));
    }

    if (tags.isEmpty && (testEnv == 'macos' || testEnv == 'windows')) {
      continue;
    }
    if (tags.isNotEmpty && !tags.contains(testEnv)) continue;

    final extraArgs = <String>[];
    if (argsFile.existsSync()) {
      for (final arg in argsFile.readAsStringSync().trim().split(
        RegExp(r'\s+'),
      )) {
        if (arg.isNotEmpty) extraArgs.add(arg);
      }
    }

    // Output expectations
    String? outContains;
    List<String> outNotContains = [];
    if (outContainsFile.existsSync()) {
      outContains = outContainsFile.readAsStringSync().trim();
    }
    if (outNotContainsFile.existsSync()) {
      outNotContains = outNotContainsFile
          .readAsStringSync()
          .trim()
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .toList();
    }

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

      test(
        'applies, verifies, and is idempotent',
        () async {
          if (setupScript.existsSync()) {
            final setupResult = await Process.run('bash', [setupScript.path]);
            expect(
              setupResult.exitCode,
              0,
              reason:
                  'setup.sh failed: ${setupResult.stdout}\n${setupResult.stderr}',
            );
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
              ...extraArgs,
            ]);
          } on CliExitException catch (e) {
            fail('configr apply failed (exit ${e.exitCode}):\n$out$err');
          }

          // Verify output content
          final combinedOut = '$out\n$err';
          if (outContains != null) {
            expect(combinedOut, contains(outContains));
          }
          for (final forbidden in outNotContains) {
            expect(combinedOut, isNot(contains(forbidden)));
          }

          if (verifyScript.existsSync()) {
            final verifyResult = await Process.run('bash', [verifyScript.path]);
            expect(
              verifyResult.exitCode,
              0,
              reason:
                  'verify.sh failed:\n${verifyResult.stdout}\n${verifyResult.stderr}',
            );
          }

          // Second apply for idempotency check
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
              ...extraArgs,
            ]);
          } on CliExitException catch (e) {
            fail(
              'Second apply (idempotency) failed (exit ${e.exitCode}):\n$out2$err2',
            );
          }

          if (testRollback || verifyRollbackScript.existsSync()) {
            final rollbackOut = StringBuffer();
            final rollbackErr = StringBuffer();
            final rollbackRunner = ConfigrCommandRunner(
              out: (s) => rollbackOut.write(s),
              err: (s) => rollbackErr.write(s),
            );

            try {
              await rollbackRunner.run([
                '--no-interaction',
                'rollback',
                '--v2',
                '--config',
                configFile.path,
              ]);
            } on CliExitException catch (e) {
              fail(
                'configr rollback failed (exit ${e.exitCode}):\n'
                '$rollbackOut$rollbackErr',
              );
            }

            if (verifyRollbackScript.existsSync()) {
              final verifyRollbackResult = await Process.run('bash', [
                verifyRollbackScript.path,
              ]);
              expect(
                verifyRollbackResult.exitCode,
                0,
                reason:
                    'verify_rollback.sh failed:\n'
                    '${verifyRollbackResult.stdout}\n'
                    '${verifyRollbackResult.stderr}',
              );
            }
          }
        },
        tags: tags.isEmpty ? null : tags,
        timeout: const Timeout(Duration(minutes: 2)),
      );
    });
  }
}
