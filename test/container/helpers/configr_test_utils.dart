import 'dart:io';

import 'package:test/test.dart';

const _projectDir = '/app';
const _configrBin = 'bin/configr.dart';

/// Result of running [configrApply] or [configrDryRun].
class ConfigrResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  ConfigrResult(this.exitCode, this.stdout, this.stderr);

  bool get isSuccess => exitCode == 0;
  bool get isDryRun => stdout.contains('DRY-RUN') || stdout.contains('dry-run');
  bool get isChanged =>
      stdout.contains('changed') || stderr.contains('changed');
}

String _dynamicToString(dynamic value) {
  if (value is String) return value.trim();
  if (value is List<int>) return String.fromCharCodes(value).trim();
  return '$value'.trim();
}

/// Writes [configText] to a temp file and runs `configr apply`.
Future<ConfigrResult> configrApply(
  String configText, {
  bool dryRun = false,
}) async {
  final configFile =
      '/tmp/configr_test_${DateTime.now().millisecondsSinceEpoch}.i3';
  try {
    await File(configFile).writeAsString(configText);

    final args = ['run', _configrBin, 'apply', '--config', configFile];
    if (dryRun) args.add('--dry-run');

    final result = await Process.run(
      'dart',
      args,
      workingDirectory: _projectDir,
    );

    return ConfigrResult(
      result.exitCode,
      _dynamicToString(result.stdout),
      _dynamicToString(result.stderr),
    );
  } finally {
    try {
      await File(configFile).delete();
    } catch (_) {}
  }
}

/// Asserts idempotency: first run succeeds, second run produces no change.
Future<void> assertIdempotent(String configText) async {
  final first = await configrApply(configText);
  expect(
    first.isSuccess,
    isTrue,
    reason:
        'First apply failed:\nstdout: ${first.stdout}\nstderr: ${first.stderr}',
  );

  final second = await configrApply(configText);
  expect(
    second.isSuccess,
    isTrue,
    reason:
        'Second apply (idempotent) failed:\nstdout: ${second.stdout}\nstderr: ${second.stderr}',
  );
  expect(
    second.isChanged,
    isFalse,
    reason:
        'Second apply should produce no change:\nstdout: ${second.stdout}\nstderr: ${second.stderr}',
  );
}

/// Asserts check-mode (dry-run) shows what would change without modifying state.
Future<List<ConfigrResult>> assertCheckMode(
  String configText, {
  Future<void> Function()? verifyStateBefore,
  Future<void> Function()? verifyStateAfter,
}) async {
  if (verifyStateBefore != null) await verifyStateBefore();

  final dry = await configrApply(configText, dryRun: true);
  expect(
    dry.isSuccess,
    isTrue,
    reason: 'Dry-run failed:\nstdout: ${dry.stdout}\nstderr: ${dry.stderr}',
  );
  expect(
    dry.isDryRun,
    isTrue,
    reason: 'Output should indicate dry-run mode:\nstdout: ${dry.stdout}',
  );

  if (verifyStateAfter != null) await verifyStateAfter();

  return [dry];
}

/// Creates a YAML-style map tag for [key] with [value] for inline config.
String yamlTag(String key, String value) => '$key = "$value"';

/// Runs a shell command and returns parsed stdout lines.
Future<List<String>> shellLines(String command) async {
  final result = await Process.run('sh', ['-c', command]);
  if (result.exitCode != 0) return [];
  return _dynamicToString(
    result.stdout,
  ).split('\n').where((l) => l.isNotEmpty).toList();
}

/// Runs a shell command and returns the trimmed stdout.
Future<String> shell(String command) async {
  final result = await Process.run('sh', ['-c', command]);
  return _dynamicToString(result.stdout);
}
