import 'dart:io' as io;

import 'package:configr/src/strategies/hook_strategy.dart';
import 'package:configr/src/utils/execution_service.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:lualike/lualike.dart' show ProcessBackend;
import 'package:path/path.dart' as p;

import 'lua_hook_runner.dart';

class HookManager {
  final String hooksDir;
  final FileSystem _fileSystem;
  final FileSystem _scriptFileSystem;
  final ExecutionService? executionService;
  final ProcessBackend? _processBackend;
  final Map<String, String> extraEnv;
  final String _hookRunId;

  HookManager({
    required this.hooksDir,
    FileSystem? fileSystem,
    FileSystem? scriptFileSystem,
    this.executionService,
    this._processBackend,
    this.extraEnv = const {},
  }) : _fileSystem = fileSystem ?? const LocalFileSystem(),
       _scriptFileSystem =
           scriptFileSystem ?? fileSystem ?? const LocalFileSystem(),
       _hookRunId = DateTime.now().toUtc().toIso8601String();

  static const knownEvents = [
    'pre-apply',
    'post-apply',
    'pre-block',
    'post-block',
    'pre-connect',
    'on-error',
  ];

  Future<bool> hasEvent(String event) async =>
      await _findHookFile(event) != null;

  Future<bool> runEvent(
    String event, {
    Map<String, dynamic> extraVars = const {},
  }) async {
    final hookFile = await _findHookFile(event);
    if (hookFile == null) return false;

    final hookLogger = logger.withContext({
      'hookEvent': event,
      'hookFile': p.basename(hookFile),
    });
    hookLogger.info('Running hook.');

    try {
      if (hookFile.endsWith('.lua')) {
        return await _runLuaHook(hookFile, event, extraVars);
      }
      return await _runShellHook(hookFile, event, extraVars);
    } catch (e) {
      hookLogger.withContext({'error': '$e'}).warning('Hook failed.');
      return false;
    }
  }

  Future<String?> _findHookFile(String event) async {
    final dir = _scriptFileSystem.directory(hooksDir);
    if (!await dir.exists()) return null;

    await for (final entry in dir.list()) {
      if (entry is! File) continue;
      final stem = p.basenameWithoutExtension(entry.path);
      if (stem == event) return entry.path;
    }
    return null;
  }

  Future<bool> _runLuaHook(
    String scriptPath,
    String event,
    Map<String, dynamic> extraVars,
  ) async {
    final globals = <String, dynamic>{
      'event_name': event,
      'hook_run_id': _hookRunId,
      ...extraEnv,
      ...extraVars,
    };

    final runner = LuaHookRunner(
      globals: globals,
      fileSystem: _fileSystem,
      scriptFileSystem: _scriptFileSystem,
      processBackend: _processBackend,
    );

    return runner.run(scriptPath);
  }

  Future<bool> _runShellHook(
    String scriptPath,
    String event,
    Map<String, dynamic> extraVars,
  ) async {
    final env = Map<String, String>.from(extraEnv);
    env['CONFIGR_EVENT'] = event;
    env['CONFIGR_HOOK_RUN_ID'] = _hookRunId;
    for (final entry in extraEnv.entries) {
      env['CONFIGR_${entry.key.toUpperCase()}'] = entry.value;
    }
    for (final entry in extraVars.entries) {
      env['CONFIGR_${entry.key.toUpperCase()}'] = entry.value.toString();
    }

    final result = await _runBashHookScript(scriptPath, env);

    if (result.exitCode != 0) {
      logger
          .withContext({
            'hookEvent': event,
            'hookFile': p.basename(scriptPath),
            'exitCode': result.exitCode,
            'stderr': '${result.stderr}',
          })
          .warning('Hook exited with a non-zero status.');
      return false;
    }

    return true;
  }

  Future<io.ProcessResult> _runBashHookScript(
    String scriptPath,
    Map<String, String> environment,
  ) async {
    final runtimeExecutionService =
        executionService ?? const LocalExecutionService();

    final script = await _scriptFileSystem.file(scriptPath).readAsString();
    final tempDir = await io.Directory.systemTemp.createTemp('configr-hook-');
    final localScript = io.File(
      '${tempDir.path}${io.Platform.pathSeparator}${p.basename(scriptPath)}',
    );

    try {
      await localScript.writeAsString(script);
      final hookStrategy = HookStrategy.forPlatform(
        runtimeExecutionService.platform,
      );

      if (runtimeExecutionService is LocalExecutionService) {
        final (exe, args) = hookStrategy.runScript(localScript.path);
        return runtimeExecutionService.run(exe, args, environment: environment);
      }

      final remotePath = await _createRemoteHookPath(
        runtimeExecutionService,
        hookStrategy,
        p.basename(scriptPath),
      );
      await runtimeExecutionService.putFile(localScript.path, remotePath);
      try {
        final (exe, args) = hookStrategy.runScript(remotePath);
        return await runtimeExecutionService.run(
          exe,
          args,
          environment: environment,
        );
      } finally {
        final (rmExe, rmArgs) = hookStrategy.removeFile(remotePath);
        await runtimeExecutionService.run(rmExe, rmArgs);
      }
    } finally {
      await tempDir.delete(recursive: true);
    }
  }

  Future<String> _createRemoteHookPath(
    ExecutionService executionService,
    HookStrategy hookStrategy,
    String scriptName,
  ) async {
    final (exe, args) = hookStrategy.tempFilePath(_safeTempSuffix(scriptName));
    final result = await executionService.run(exe, args);
    if (result.exitCode != 0) {
      throw StateError(
        'Could not allocate target hook temp file: ${result.stderr}',
      );
    }
    final path = result.stdout.toString().trim();
    if (path.isEmpty) {
      throw StateError('Target hook temp file command returned an empty path.');
    }
    return path;
  }

  String _safeTempSuffix(String scriptName) {
    final safe = scriptName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return safe.isEmpty ? 'hook' : safe;
  }
}
