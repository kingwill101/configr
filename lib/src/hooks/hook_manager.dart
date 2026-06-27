import 'dart:io';

import 'package:configr/src/utils/logging.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;

import 'lua_hook_runner.dart';

class HookManager {
  final String hooksDir;
  final FileSystem _fileSystem;
  final Map<String, String> _extraEnv;

  HookManager({
    required this.hooksDir,
    FileSystem? fileSystem,
    Map<String, String> extraEnv = const {},
  })  : _fileSystem = fileSystem ?? const LocalFileSystem(),
        _extraEnv = extraEnv;

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

    logger.info('Running $event hook: ${p.basename(hookFile)}');

    try {
      if (hookFile.endsWith('.lua')) {
        return await _runLuaHook(hookFile, event, extraVars);
      }
      return await _runShellHook(hookFile, event, extraVars);
    } catch (e) {
      logger.warning('$event hook failed: $e');
      return false;
    }
  }

  String? _findHookFile(String event) {
    final dir = _fileSystem.directory(hooksDir);
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
      logger.warning(
        '$event hook exited with code ${result.exitCode}: ${result.stderr}',
      );
      return false;
    }

    return true;
  }
}
