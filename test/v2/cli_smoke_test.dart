import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:configr/src/cli/configr_command_runner.dart';
import 'package:configr/src/cli/cli_exit_exception.dart';
import 'package:configr/src/di.dart';
import 'package:configr/src/utils/event_bus.dart';

/// CLI smoke tests for the `configr` CLI.
///
/// These tests invoke [ConfigrCommandRunner] directly instead of via
/// [Process.run] so they are faster and support DI injection without
/// pre-compiling a binary.
///
/// To run:
/// ```sh
/// dart test test/v2/cli_smoke_test.dart
/// ```
late Directory tempDir;
late String configPath;
final _stdoutBuffer = StringBuffer();
final _stderrBuffer = StringBuffer();

void main() {
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('configr_v2_test_');
    configPath = p.join(tempDir.path, 'config');
    _stdoutBuffer.clear();
    _stderrBuffer.clear();

    di
      ..allowReassignment = true
      ..registerSingleton<EventBus>(EventBus())
      ..allowReassignment = false;
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  group('configr CLI smoke tests', () {
    test('--version prints embedded build metadata', () async {
      final exitCode = await _runRunner(['--version']);
      expect(exitCode, equals(0));

      final output = _stdoutBuffer.toString();
      expect(output, contains('configr'));
      expect(output, contains('version:'));
      expect(output, contains('gitSha:'));
      expect(output, contains('buildDate:'));
      expect(output, contains('buildTarget:'));
    });

    test('apply --help shows usage info', () async {
      final exitCode = await _runRunner(['apply', '--help']);
      expect(exitCode, equals(0));
      expect(_stdoutBuffer.toString(), contains('Apply configuration'));
      expect(_stdoutBuffer.toString(), contains('force'));
      expect(_stdoutBuffer.toString(), contains('dry-run'));
      expect(_stdoutBuffer.toString(), contains('fail-fast'));
    });

    test('apply with empty config succeeds', () async {
      await _writeConfig('');
      final exitCode = await _runRunner(['apply']);
      expect(exitCode, equals(0));
      expect(_stdoutBuffer.toString(), contains('Apply Configuration'));
      expect(
        _stdoutBuffer.toString(),
        contains('Configuration applied successfully'),
      );
    });

    test('apply with echo block', () async {
      await _writeConfig('''
echo {
  message = "Hello from CLI test"
}
''');
      final exitCode = await _runRunner(['apply']);
      expect(exitCode, equals(0));
      expect(_stdoutBuffer.toString(), contains('Apply Configuration'));
      expect(_stdoutBuffer.toString(), contains('Hello from CLI test'));
      expect(
        _stdoutBuffer.toString(),
        contains('Configuration applied successfully'),
      );
    });

    test('apply --dry-run parses but does not execute', () async {
      await _writeConfig('''
echo {
  message = "Should not execute"
}
''');
      final exitCode = await _runRunner(['apply', '--dry-run']);
      expect(exitCode, equals(0));
      expect(_stdoutBuffer.toString(), contains('DRY-RUN'));
      expect(_stdoutBuffer.toString(), contains('Would write lockfile'));
    });

    test('apply with --dry-run does not write lockfile', () async {
      await _writeConfig('''
echo {
  message = "test"
}
''');
      await _runRunner(['apply', '--dry-run']);
      final lockFile = File(p.join(tempDir.path, 'config.lock.json'));
      expect(await lockFile.exists(), isFalse);
    });

    test('apply with failing block exits with code 1', () async {
      await _writeConfig('''
	validate {
	  source = "/nonexistent/file.json"
	  format = "json"
	}
	''');
      final exitCode = await _runRunner(['apply', '--fail-fast']);
      expect(exitCode, equals(1));
      expect(_stdoutBuffer.toString(), contains('Apply Configuration'));
    });

    test('apply writes lockfile on success', () async {
      await _writeConfig('''
	echo {
	  message = "test"
	}
	''');
      await _runRunner(['apply']);
      final lockFile = File(p.join(tempDir.path, 'config.lock.json'));
      expect(await lockFile.exists(), isTrue);

      final content = await lockFile.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      expect(data['config_checksum'], isA<String>());
      expect(data['applied_blocks'], isA<List>());
      expect((data['applied_blocks'] as List).length, greaterThan(0));
    });

    test('apply --force re-applies even when lockfile exists', () async {
      await _writeConfig('''
echo {
  message = "first pass"
}
''');
      await _runRunner(['apply']);

      final exitCode2 = await _runRunner(['apply']);
      expect(exitCode2, equals(0));
      expect(
        _stdoutBuffer.toString(),
        contains('Configuration applied successfully'),
      );

      final exitCode3 = await _runRunner(['apply', '--force']);
      expect(exitCode3, equals(0));
      expect(
        _stdoutBuffer.toString(),
        contains('Configuration applied successfully'),
      );
    });

    test('rollback rolls back applied blocks', () async {
      await _writeConfig('''
echo {
  message = "rollback test"
}
''');
      await _runRunner(['apply']);

      final exitCode = await _runRunner(['rollback']);
      expect(exitCode, equals(0));
      expect(_stdoutBuffer.toString(), contains('Rollback Configuration'));
      expect(
        _stdoutBuffer.toString(),
        contains('Rollback completed successfully'),
      );
    });

    test('status shows block summary', () async {
      await _writeConfig('''
echo {
  message = "status test"
}
''');
      final exitCode = await _runRunner(['status']);
      expect(exitCode, equals(0));
      expect(_stdoutBuffer.toString(), contains('Configuration Status'));
      expect(_stdoutBuffer.toString(), contains('echo'));
    });

    test('diff shows block differences', () async {
      await _writeConfig('''
echo {
  message = "diff test"
}
copy {
  source = "/src"
  destination = "/dst"
}
''');
      final exitCode = await _runRunner(['diff']);
      expect(exitCode, equals(0));
      expect(_stdoutBuffer.toString(), contains('Configuration Diff'));
      expect(_stdoutBuffer.toString(), contains('echo'));
      expect(_stdoutBuffer.toString(), contains('copy'));
      expect(_stdoutBuffer.toString(), contains('2 action block(s)'));
    });

    test('run executes named command from config', () async {
      final outputPath = p.join(tempDir.path, 'named-command-output');
      await _writeConfig('''
commands {
  command "write-file" {
    command = "touch"
    parameters "$outputPath"
  }
}
''');

      final exitCode = await _runRunner(['run', 'write-file']);

      expect(exitCode, equals(0));
      expect(_stdoutBuffer.toString(), contains('Run Command'));
      expect(
        _stdoutBuffer.toString(),
        contains('Command "write-file" completed successfully'),
      );
      expect(await File(outputPath).exists(), isTrue);
    });

    test('format formats config file', () async {
      await _writeConfig('''
echo {
  message = "hello"
}
''');
      final exitCode = await _runRunner(['format']);
      expect(exitCode, equals(0));
      expect(_stdoutBuffer.toString(), contains('Format Configuration'));
      expect(_stdoutBuffer.toString(), contains('file updated in-place'));

      final formatted = await File(configPath).readAsString();
      expect(formatted, contains('message'));
      expect(formatted, contains('"hello"'));
    });
  });
}

/// Writes [content] to the test config file.
Future<void> _writeConfig(String content) async {
  await File(configPath).writeAsString(content);
}

/// Runs [ConfigrCommandRunner] with [args].
///
/// Always appends `--no-interaction` and `--config <configPath>` so the
/// runner uses CLI mode (no interactive prompts) and targets the test
/// config file.
///
/// Returns the exit code (0 on success, 1+ on CliExitException).
Future<int> _runRunner(List<String> args) async {
  final runner = ConfigrCommandRunner(
    out: (line) => _stdoutBuffer.writeln(line),
    err: (line) => _stderrBuffer.writeln(line),
    outRaw: (text) => _stdoutBuffer.write(text),
    errRaw: (text) => _stderrBuffer.write(text),
  );
  try {
    await runner.run(['--no-interaction', ...args, '--config', configPath]);
    return 0;
  } on CliExitException catch (e) {
    return e.exitCode;
  }
}
