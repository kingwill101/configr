import 'dart:io';

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
  final ProcessBackend? _processBackend;
  final Map<String, String> _extraEnv;

  HookManager({
    required this.hooksDir,
    FileSystem? fileSystem,
    FileSystem? scriptFileSystem,
    this._processBackend,
    this._extraEnv = const {},
  }) : _fileSystem = fileSystem ?? const LocalFileSystem(),
       _scriptFileSystem =
           scriptFileSystem ?? fileSystem ?? const LocalFileSystem();

  static const knownEvents = [
    'pre-apply',
    'post-apply',
    'pre-block',
    'post-block',
    'pre-connect',
    'on-error',
  ];

  bool hasEvent(String event) => _findHookFile(event) != null;

  Future<bool> runEvent(
    String event, {
    Map<String, dynamic> extraVars = const {},
  }) async {
    final hookFile = _findHookFile(event);
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

  String? _findHookFile(String event) {
    final dir = _scriptFileSystem.directory(hooksDir);
    if (!dir.existsSync()) return null;

    final entries = dir.listSync().whereType<File>();
    for (final entry in entries) {
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
      ..._extraEnv,
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
    final env = Map<String, String>.from(_extraEnv);
    env['CONFIGR_EVENT'] = event;
    for (final entry in extraVars.entries) {
      env['CONFIGR_${entry.key.toUpperCase()}'] = entry.value.toString();
    }

    final result = await Process.run(
      '/bin/sh',
      [scriptPath],
      runInShell: false,
      environment: env,
    );

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
}
