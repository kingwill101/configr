@Tags(['integration'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:configr/src/cli/configr_command_runner.dart';
import 'package:configr/src/cli/cli_exit_exception.dart';
import 'lua_fixture_runner.dart';

/// Resolves a script path by preferring Lua (.lua) over shell (.sh).
String? _resolveScript(Directory dir, String name) {
  final lua = File('${dir.path}/$name.lua');
  final sh = File('${dir.path}/$name.sh');
  if (lua.existsSync()) return lua.path;
  if (sh.existsSync()) return sh.path;
  return null;
}

/// Runs a Lua or shell script and returns the result.
Future<ProcessResult> _runScript(String scriptPath) async {
  if (scriptPath.endsWith('.lua')) {
    final runner = LuaFixtureRunner();
    return runner.run(scriptPath);
  }
  return Process.run('bash', [scriptPath]);
}

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
    final setupScript = _resolveScript(dir, 'setup');
    final verifyScript = _resolveScript(dir, 'verify');
    final verifyRollbackScript = _resolveScript(dir, 'verify_rollback');
    final cleanupScript = _resolveScript(dir, 'cleanup');
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
      tearDown(() async {
        if (cleanupScript != null) {
          await _runScript(cleanupScript);
        }
        final lockFile = File('${configFile.path}.lock.json');
        if (lockFile.existsSync()) lockFile.deleteSync();
      });

      test(
        'applies, verifies, and is idempotent',
        () async {
          if (setupScript != null) {
            final setupResult = await _runScript(setupScript);
            expect(
              setupResult.exitCode,
              0,
              reason:
                  'setup failed: ${setupResult.stdout}\n${setupResult.stderr}',
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

          if (verifyScript != null) {
            final verifyResult = await _runScript(verifyScript);
            expect(
              verifyResult.exitCode,
              0,
              reason:
                  'verify failed:\n${verifyResult.stdout}\n${verifyResult.stderr}',
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

          if (testRollback || verifyRollbackScript != null) {
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

            if (verifyRollbackScript != null) {
              final verifyRollbackResult = await _runScript(
                verifyRollbackScript,
              );
              expect(
                verifyRollbackResult.exitCode,
                0,
                reason:
                    'verify_rollback failed:\n'
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
