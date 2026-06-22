import 'dart:convert';
import 'dart:io';

import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/file_utils.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:i3config/i3config_v2.dart' as i3;
import 'package:path/path.dart' as path;

/// Block handler for the `git` config action.
///
/// Performs Git operations — clone, pull, push, commit.
///
/// ```i3
/// git {
///   source = "https://github.com/user/repo.git"
///   destination = "/path/to/repo"
///   branch = "main"
///   operation = "clone"          # clone | pull | push | commit
///   commit_message = "my commit"
///   stream_output = true
/// }
/// ```
class GitBlock extends ActionBlock {
  @override
  String get blockType => 'git';

  // ---------------------------------------------------------------------------
  // Git-specific properties
  // ---------------------------------------------------------------------------

  String? repositoryUrl;
  String? branch;
  String? commitMessage;
  String operation = 'clone';
  bool streamOutput = true;

  // ---------------------------------------------------------------------------
  // Execution state
  // ---------------------------------------------------------------------------

  String? lastCommitHash;
  int operationDurationMs = 0;
  String? operationOutput;
  String? operationError;
  bool operationSuccess = false;

  GitBlock({super.fileSystem, super.eventBus});

  // ---------------------------------------------------------------------------
  // Handler pipeline
  // ---------------------------------------------------------------------------

  @override
  Map<String, String> get additionalProperties => {
    if (branch != null) 'branch': branch!,
    if (commitMessage != null) 'commit_message': commitMessage!,
    if (operation != 'clone') 'operation': operation,
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (!streamOutput) 'stream_output': streamOutput,
  };



  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);

    repositoryUrl = source.isNotEmpty ? source : null;
    branch = context.getVariable('branch') as String?;
    commitMessage = context.getVariable('commit_message') as String?;
    operation = (context.getVariable('operation') as String?) ?? 'clone';

    streamOutput = switch (context.getVariable('stream_output')) {
      false || 'false' => false,
      _ => true,
    };
  }

  // ---------------------------------------------------------------------------
  // Execution
  // ---------------------------------------------------------------------------

  @override
  Future<void> execute() async {
    emitEvent(
      StartedEvent(
        moduleId: id,
        message: 'Starting git $operation: $source → $destination',
      ),
    );

    try {
      switch (operation) {
        case 'clone':
          await _executeClone();
          break;
        case 'pull':
          await _executePull();
          break;
        case 'push':
          await _executePush();
          break;
        case 'commit':
          await _executeCommit();
          break;
        default:
          throw ActionFailedException(
            'Unknown git operation: $operation',
            moduleId: id,
          );
      }

      operationSuccess = true;
      emitEvent(
        CompletedEvent(moduleId: id, message: 'Git $operation completed'),
      );
    } catch (e, _) {
      operationSuccess = false;
      emitEvent(
        FailedEvent(moduleId: id, message: 'Git $operation failed: $e'),
      );
      throw ActionFailedException(
        'Git $operation failed: $source',
        cause: e,
        moduleId: id,
      );
    }

    status = 'completed';
  }

  @override
  Future<void> rollback() async {
    switch (operation) {
      case 'clone':
        await _rollbackClone();
        break;
      case 'pull':
        await _rollbackPull();
        break;
      case 'commit':
        await _rollbackCommit();
        break;
      case 'push':
        // Cannot rollback a push
        logger.warning('Cannot rollback git push operation');
        break;
    }

    for (final child in children) {
      await child.rollback();
    }
  }

  // ---------------------------------------------------------------------------
  // Clone implementation
  // ---------------------------------------------------------------------------

  Future<void> _executeClone() async {
    if (repositoryUrl == null || repositoryUrl!.isEmpty) {
      throw ActionFailedException(
        'Repository URL is required for clone',
        moduleId: id,
      );
    }

    // Check if destination already exists
    if (await FileUtils.directoryExists(destination, fileSystem: fileSystem)) {
      logger.info('Repository already exists at $destination, skipping clone');
      return;
    }

    // Ensure parent directory exists
    final parentDir = path.dirname(destination);
    if (!await FileUtils.directoryExists(parentDir, fileSystem: fileSystem)) {
      await FileUtils.createDirectory(parentDir, fileSystem: fileSystem);
    }

    final startTime = DateTime.now();
    final args = ['clone', repositoryUrl!, destination];
    if (branch != null && branch!.isNotEmpty) {
      args.insertAll(1, ['--branch', branch!]);
    }

    await _runGit(args, destination);
    operationDurationMs = DateTime.now().difference(startTime).inMilliseconds;
  }

  Future<void> _rollbackClone() async {
    if (await FileUtils.directoryExists(destination, fileSystem: fileSystem)) {
      logger.info('Removing cloned repository at $destination');
      await FileUtils.deleteDirectory(
        destination,
        recursive: true,
        fileSystem: fileSystem,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Pull implementation
  // ---------------------------------------------------------------------------

  Future<void> _executePull() async {
    final startTime = DateTime.now();
    final args = ['pull'];

    if (branch != null && branch!.isNotEmpty) {
      args.addAll(['origin', branch!]);
    }

    await _runGit(args, destination);
    operationDurationMs = DateTime.now().difference(startTime).inMilliseconds;

    // Get latest commit hash
    try {
      final result = await _runGit(['rev-parse', 'HEAD'], destination);
      lastCommitHash = result.stdout.toString().trim();
    } catch (_) {}
  }

  Future<void> _rollbackPull() async {
    if (lastCommitHash != null && lastCommitHash!.isNotEmpty) {
      try {
        await _runGit(['reset', '--hard', lastCommitHash!], destination);
      } catch (e) {
        logger.warning('Failed to rollback pull: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Push implementation
  // ---------------------------------------------------------------------------

  Future<void> _executePush() async {
    final startTime = DateTime.now();
    final args = ['push'];

    if (branch != null && branch!.isNotEmpty) {
      args.addAll(['origin', branch!]);
    }

    await _runGit(args, destination);
    operationDurationMs = DateTime.now().difference(startTime).inMilliseconds;
  }

  // ---------------------------------------------------------------------------
  // Commit implementation
  // ---------------------------------------------------------------------------

  Future<void> _executeCommit() async {
    if (commitMessage == null || commitMessage!.isEmpty) {
      throw ActionFailedException(
        'Commit message is required for commit operation',
        moduleId: id,
      );
    }

    final startTime = DateTime.now();

    // Stage all changes
    await _runGit(['add', '-A'], destination);

    // Commit
    await _runGit(['commit', '-m', commitMessage!], destination);

    operationDurationMs = DateTime.now().difference(startTime).inMilliseconds;

    // Get commit hash
    try {
      final result = await _runGit(['rev-parse', 'HEAD'], destination);
      lastCommitHash = result.stdout.toString().trim();
    } catch (_) {}
  }

  Future<void> _rollbackCommit() async {
    if (lastCommitHash != null && lastCommitHash!.isNotEmpty) {
      try {
        // Reset to previous commit
        await _runGit(['reset', '--soft', 'HEAD~1'], destination);
      } catch (e) {
        logger.warning('Failed to rollback commit: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Git execution helper
  // ---------------------------------------------------------------------------

  Future<ProcessResult> _runGit(List<String> args, String workingDir) async {
    final fullArgs = ['-C', workingDir, ...args];
    final output = StringBuffer();
    final error = StringBuffer();

    if (streamOutput) {
      emitEvent(
        StatusUpdateEvent(
          moduleId: id,
          level: StatusEvent.info,
          message: 'Running: git ${args.join(' ')}',
        ),
      );
    }

    final process = await Process.start(
      'git',
      fullArgs,
      workingDirectory: workingDir,
    );

    await Future.wait([
      process.stdout.transform(utf8.decoder).forEach((d) {
        output.write(d);
        if (streamOutput) {
          emitEvent(
            StatusUpdateEvent(
              moduleId: id,
              level: StatusEvent.debug,
              message: d.trim(),
            ),
          );
        }
      }),
      process.stderr.transform(utf8.decoder).forEach((d) {
        error.write(d);
        if (streamOutput) {
          emitEvent(
            StatusUpdateEvent(
              moduleId: id,
              level: StatusEvent.debug,
              message: d.trim(),
            ),
          );
        }
      }),
    ]);

    final exitCode = await process.exitCode;
    operationOutput = output.toString();
    operationError = error.toString();

    if (exitCode != 0) {
      throw ActionFailedException(
        'Git command failed: ${error.toString().trim()}',
        moduleId: id,
      );
    }

    return ProcessResult(
      process.pid,
      exitCode,
      output.toString(),
      error.toString(),
    );
  }
}
