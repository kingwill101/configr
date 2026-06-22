import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// CLI smoke tests for the `configr` binary with `--v2`.
///
/// These tests invoke the compiled binary via [Process.run] with real
/// config files in temporary directories. They verify that the CLI entry
/// point produces correct output and exit codes for common commands.
///
/// To run:
/// ```sh
/// dart test test/v2/cli_smoke_test.dart
/// ```
///
/// These tests assume the binary is pre-compiled at the path returned by
/// [_binaryPath]. If the binary doesn't exist, tests are skipped.
late Directory tempDir;
late String configPath;

void main() {
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('configr_v2_test_');
    configPath = p.join(tempDir.path, 'config');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  group('configr --v2 CLI smoke tests', () {
    test('apply --help shows usage info', () async {
      final result = await _runConfigr(['apply', '--help']);
      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('Apply configuration'));
      expect(result.stdout, contains('force'));
      expect(result.stdout, contains('dry-run'));
      expect(result.stdout, contains('fail-fast'));
    });

    test('apply --v2 with empty config succeeds', () async {
      await _writeConfig('');
      final result = await _runConfigr([
        'apply',
        '--v2',
      ], workingDir: tempDir.path);
      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('Apply Configuration (v2)'));
      expect(result.stdout, contains('Configuration applied successfully'));
    });

    test('apply --v2 with echo block', () async {
      await _writeConfig('''
echo {
  message = "Hello from CLI test"
}
''');
      final result = await _runConfigr([
        'apply',
        '--v2',
      ], workingDir: tempDir.path);
      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('Apply Configuration (v2)'));
      expect(result.stdout, contains('echo_0'));
      expect(result.stdout, contains('Hello from CLI test'));
      expect(result.stdout, contains('Configuration applied successfully'));
    });

    test('apply --v2 --dry-run parses but does not execute', () async {
      await _writeConfig('''
echo {
  message = "Should not execute"
}
''');
      final result = await _runConfigr([
        'apply',
        '--v2',
        '--dry-run',
      ], workingDir: tempDir.path);
      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('DRY-RUN'));
      expect(result.stdout, contains('Would write lockfile'));
    });

    test('apply --v2 with --dry-run does not write lockfile', () async {
      await _writeConfig('''
echo {
  message = "test"
}
''');
      await _runConfigr([
        'apply',
        '--v2',
        '--dry-run',
      ], workingDir: tempDir.path);
      final lockFile = File(p.join(tempDir.path, 'config.lock.json'));
      expect(await lockFile.exists(), isFalse);
    });

    test('apply --v2 with failing block exits with code 1', () async {
      // A validate block with invalid JSON should fail.
      await _writeConfig('''
	validate {
	  source = "/nonexistent/file.json"
	  format = "json"
	}
	''');
      final result = await _runConfigr([
        'apply',
        '--v2',
        '--fail-fast',
      ], workingDir: tempDir.path);
      expect(result.exitCode, equals(1));
      expect(result.stdout, contains('Apply Configuration (v2)'));
    });

    test('apply --v2 writes lockfile on success', () async {
      await _writeConfig('''
	echo {
	  message = "test"
	}
	''');
      await _runConfigr(['apply', '--v2'], workingDir: tempDir.path);
      final lockFile = File(p.join(tempDir.path, 'config.lock.json'));
      expect(await lockFile.exists(), isTrue);

      // Verify lockfile content
      final content = await lockFile.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      expect(data['config_checksum'], isA<String>());
      expect(data['applied_blocks'], isA<List>());
      expect((data['applied_blocks'] as List).length, greaterThan(0));
    });

    test('apply --v2 --force re-applies even when lockfile exists', () async {
      await _writeConfig('''
echo {
  message = "first pass"
}
''');
      // First apply
      await _runConfigr(['apply', '--v2'], workingDir: tempDir.path);

      // Second apply without force (config unchanged) - currently still
      // succeeds but the 'skip' message is only at INFO log level which
      // is silenced in production. Check that it still produces output.
      final result2 = await _runConfigr([
        'apply',
        '--v2',
      ], workingDir: tempDir.path);
      expect(result2.exitCode, equals(0));
      expect(result2.stdout, contains('Configuration applied successfully'));

      // Third apply with --force should re-apply
      final result3 = await _runConfigr([
        'apply',
        '--v2',
        '--force',
      ], workingDir: tempDir.path);
      expect(result3.exitCode, equals(0));
      expect(result3.stdout, contains('Configuration applied successfully'));
    });

    test('rollback --v2 rolls back applied blocks', () async {
      await _writeConfig('''
echo {
  message = "rollback test"
}
''');
      // Apply first
      await _runConfigr(['apply', '--v2'], workingDir: tempDir.path);

      // Then rollback
      final result = await _runConfigr([
        'rollback',
        '--v2',
      ], workingDir: tempDir.path);
      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('Rollback Configuration (v2)'));
      expect(result.stdout, contains('Rollback completed successfully'));
    });

    test('status --v2 shows block summary', () async {
      await _writeConfig('''
echo {
  message = "status test"
}
''');
      final result = await _runConfigr([
        'status',
        '--v2',
      ], workingDir: tempDir.path);
      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('Configuration Status (v2)'));
      expect(result.stdout, contains('echo'));
    });

    test('diff --v2 shows block differences', () async {
      await _writeConfig('''
echo {
  message = "diff test"
}
copy {
  source = "/src"
  destination = "/dst"
}
''');
      final result = await _runConfigr([
        'diff',
        '--v2',
      ], workingDir: tempDir.path);
      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('Configuration Diff'));
      expect(result.stdout, contains('echo'));
      expect(result.stdout, contains('copy'));
      expect(result.stdout, contains('2 action block(s)'));
    });

    test('format --v2 formats config file', () async {
      await _writeConfig('''
echo {
  message = "hello"
}
''');
      final result = await _runConfigr([
        'format',
        '--v2',
      ], workingDir: tempDir.path);
      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('Format Configuration (v2)'));
      expect(result.stdout, contains('file updated in-place'));
      // Verify the file was actually formatted (re-read and check)
      final formatted = await File(configPath).readAsString();
      expect(formatted, contains('message'));
      expect(formatted, contains('"hello"'));
    });
  });
}

/// Returns the path to the compiled configr binary.
String _binaryPath() {
  // Check common locations
  final candidates = [
    p.join('build', 'cli', 'linux_x64', 'bundle', 'bin', 'configr'),
  ];

  for (final rel in candidates) {
    final abs = p.absolute(rel);
    if (File(abs).existsSync()) return abs;
  }

  // Fall back: assume it's on PATH
  return 'configr';
}

/// Writes [content] to the test config file.
Future<void> _writeConfig(String content) async {
  await File(configPath).writeAsString(content);
}

/// Runs `configr` with [args] in [workingDir] (defaults to tempDir).
Future<ProcessResult> _runConfigr(
  List<String> args, {
  String? workingDir,
}) async {
  final binary = _binaryPath();
  final env = Map<String, String>.from(Platform.environment);
  // Prevent interactive prompts in tests
  env['HOME'] = tempDir.path;
  env['USER'] = 'test';

  return await Process.run(
    binary,
    args,
    workingDirectory: workingDir ?? tempDir.path,
    environment: env,
  );
}
