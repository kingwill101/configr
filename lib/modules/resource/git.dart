import 'dart:async';
import 'dart:io';
import 'package:configr/events/module_events.dart';
import 'package:configr/exceptions.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/logging.dart';
import 'package:configr/utils/event_bus.dart';
import 'package:git/git.dart';

/// Simple git module for dotfile management operations using the git package.
/// 
/// Features:
/// - Basic repository cloning
/// - Pull latest changes
/// - Push changes to remote
/// - Simple commit operations
/// - Branch management
class FileGitModule extends ResourceModule {
  // State getters
  String get repositoryUrl => state['repositoryUrl'] as String? ?? '';
  String get localPath => state['localPath'] as String? ?? '';
  String get branch => state['branch'] as String? ?? 'main';
  String get commitMessage => state['commitMessage'] as String? ?? '';
  bool get operationSuccess => state['operationSuccess'] as bool? ?? false;
  String? get lastCommitHash => state['lastCommitHash'] as String?;
  Duration get operationDuration => Duration(milliseconds: state['operationDuration'] as int? ?? 0);
  String? get operationOutput => state['operationOutput'] as String?;
  String? get operationError => state['operationError'] as String?;
  
  // Streaming and progress features
  bool get streamOutput => state['streamOutput'] as bool? ?? false;
  bool get showProgress => state['showProgress'] as bool? ?? true;
  String? get streamingOutput => state['streamingOutput'] as String?;
  int get progressPercentage => state['progressPercentage'] as int? ?? 0;

  FileGitModule(super.file, super.action,
      {super.allowedActions = const ['git'], super.fileSystem}) {
    updateState({
      'repositoryUrl': '',
      'localPath': '',
      'branch': 'main',
      'commitMessage': '',
      'operationSuccess': false,
      'lastCommitHash': null,
      'operationDuration': 0,
      'operationOutput': null,
      'operationError': null,
      'streamOutput': false,
      'showProgress': true,
      'streamingOutput': null,
      'progressPercentage': 0,
    });
  }

  @override
  Future<void> execute() async {
    // Parse configuration first to get the operation type
    updateState({
      'repositoryUrl': action.properties['repository_url'] as String? ?? '',
      'localPath': action.properties['local_path'] as String? ?? '',
      'branch': action.properties['branch'] as String? ?? 'main',
      'commitMessage': action.properties['commit_message'] as String? ?? '',
      'streamOutput': action.properties['stream_output'] == 'true',
      'showProgress': action.properties['show_progress'] != 'false', // Default to true
    });

    final operation = action.properties['operation'] as String? ?? 'clone';
    emitEvent(StartedEvent(moduleId: action.id, message: 'Starting git $operation operation'));

    await executeModules();
    if (isRollingBack) {
      return;
    }

    final startTime = DateTime.now();
    try {
      final operation = action.properties['operation'] as String? ?? 'clone';
      
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
          throw ActionFailedException('Unknown git operation: $operation', moduleId: action.id);
      }

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      updateState({'operationDuration': duration.inMilliseconds});

      logger.info('Git operation completed successfully: $operation');
      emitEvent(CompletedEvent(moduleId: action.id, message: 'Git operation $operation completed successfully in ${duration.inMilliseconds}ms'));
    } catch (e, s) {
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      
      updateState({
        'error': e.toString(),
        'stackTrace': s.toString(),
        'operationDuration': duration.inMilliseconds,
      });
      emitEvent(FailedEvent(moduleId: action.id, message: 'Git operation failed: ${e.toString()}'));
      throw ActionFailedException('Failed to execute git operation: ${e.toString()}', moduleId: action.id, cause: e, stackTrace: s);
    }

    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
    await saveState();
  }

  @override
  Future<void> rollback() async {
    emitEvent(StartedEvent(moduleId: action.id, message: 'Rolling back git operation'));
    
    try {
      final operation = action.properties['operation'] as String? ?? 'clone';
      
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
        default:
          logger.warning('No rollback available for git operation: $operation');
      }

      for (var module in childModules) {
        await module.rollback();
      }

      emitEvent(CompletedEvent(moduleId: action.id, message: 'Git rollback completed'));
      await saveState();
    } catch (e, st) {
      updateState({
        'rollbackError': e.toString(),
        'rollbackStackTrace': st.toString()
      });
      emitEvent(FailedEvent(moduleId: action.id, message: 'Git rollback failed: ${e.toString()}'));
      rethrow;
    }
  }

  /// Execute git clone operation using git package.
  Future<void> _executeClone() async {
    if (repositoryUrl.isEmpty) {
      throw ActionFailedException('Repository URL is required for clone operation', moduleId: action.id);
    }
    if (localPath.isEmpty) {
      throw ActionFailedException('Local path is required for clone operation', moduleId: action.id);
    }

    emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Cloning repository: $repositoryUrl'));
    
    try {
      // Check if directory already exists and handle accordingly
      final directory = Directory(localPath);
      if (directory.existsSync()) {
        // Check if it's already a git repository
        final isGitRepo = await GitDir.isGitDir(localPath);
        if (isGitRepo) {
          // It's already a git repo, just update it instead of cloning
          logger.info('Directory already exists as git repository, updating instead of cloning');
          final gitDir = await GitDir.fromExisting(localPath);
          await gitDir.runCommand(['fetch', 'origin']);
          await gitDir.runCommand(['checkout', branch]);
          await gitDir.runCommand(['reset', '--hard', 'origin/$branch']);
        } else {
          // Directory exists but is not a git repo, remove it and clone
          logger.info('Directory exists but is not a git repository, removing and cloning');
          await directory.delete(recursive: true);
          await _performClone();
        }
      } else {
        // Directory doesn't exist, proceed with normal clone
        await _performClone();
      }

      // Validate that the clone was successful
      if (!directory.existsSync()) {
        throw ActionFailedException('Clone directory was not created: $localPath', moduleId: action.id);
      }

      // Validate that it's a git repository
      final gitDir = await GitDir.fromExisting(localPath);
      final isGitRepo = await GitDir.isGitDir(localPath);
      if (!isGitRepo) {
        throw ActionFailedException('Cloned directory is not a valid git repository: $localPath', moduleId: action.id);
      }

      // Validate that we're on the correct branch
      final currentBranch = await gitDir.runCommand(['branch', '--show-current']);
      final actualBranch = currentBranch.stdout.trim();
      if (actualBranch != branch) {
        logger.warning('Expected branch $branch but got $actualBranch');
      }

      updateState({
        'operationSuccess': true,
        'operationOutput': 'Successfully cloned repository to $localPath on branch $actualBranch',
        'operationError': null,
      });

      logger.info('Successfully cloned repository from $repositoryUrl to $localPath on branch $actualBranch');
    } catch (e) {
      updateState({
        'operationSuccess': false,
        'operationOutput': null,
        'operationError': e.toString(),
      });
      throw ActionFailedException('Git clone failed: ${e.toString()}', moduleId: action.id);
    }
  }

  /// Helper method to perform the actual git clone operation.
  Future<void> _performClone() async {
    if (streamOutput) {
      // Stream output directly to console for real-time feedback
      await runGit([
        'clone',
        '--progress', // Show progress for clone operations
        '--branch', branch,
        repositoryUrl,
        localPath,
      ], echoOutput: true);
    } else {
      // Use the git package's runGit function for cloning
      await runGit([
        'clone',
        '--branch', branch,
        repositoryUrl,
        localPath,
      ]);
    }
  }

  /// Execute git pull operation using git package.
  Future<void> _executePull() async {
    if (localPath.isEmpty) {
      throw ActionFailedException('Local path is required for pull operation', moduleId: action.id);
    }

    emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Pulling latest changes'));
    
    try {
      // Validate that the directory exists and is a git repo
      final directory = Directory(localPath);
      if (!directory.existsSync()) {
        throw ActionFailedException('Local directory does not exist: $localPath', moduleId: action.id);
      }

      final isGitRepo = await GitDir.isGitDir(localPath);
      if (!isGitRepo) {
        throw ActionFailedException('Directory is not a git repository: $localPath', moduleId: action.id);
      }

      final gitDir = await GitDir.fromExisting(localPath);
      
      // Get the commit hash before pull
      final beforePull = await gitDir.runCommand(['rev-parse', 'HEAD']);
      final beforeCommit = beforePull.stdout.trim();

      // Perform the pull with optional streaming
      if (streamOutput) {
        await runGit(['pull', 'origin', branch], 
          echoOutput: true, 
          processWorkingDir: localPath);
      } else {
        await gitDir.runCommand(['pull', 'origin', branch]);
      }

      // Get the commit hash after pull
      final afterPull = await gitDir.runCommand(['rev-parse', 'HEAD']);
      final afterCommit = afterPull.stdout.trim();

      // Validate that the pull actually did something or was already up to date
      final pullStatus = await gitDir.runCommand(['status', '--porcelain=v1']);
      final hasChanges = pullStatus.stdout.trim().isNotEmpty;

      String outputMessage;
      if (beforeCommit != afterCommit) {
        outputMessage = 'Successfully pulled changes from $beforeCommit to $afterCommit';
      } else if (hasChanges) {
        outputMessage = 'Repository is up to date, but has local changes';
      } else {
        outputMessage = 'Repository is already up to date with remote';
      }

      updateState({
        'operationSuccess': true,
        'operationOutput': outputMessage,
        'operationError': null,
      });

      logger.info(outputMessage);
    } catch (e) {
      updateState({
        'operationSuccess': false,
        'operationOutput': null,
        'operationError': e.toString(),
      });
      throw ActionFailedException('Git pull failed: ${e.toString()}', moduleId: action.id);
    }
  }

  /// Execute git push operation using git package.
  Future<void> _executePush() async {
    if (localPath.isEmpty) {
      throw ActionFailedException('Local path is required for push operation', moduleId: action.id);
    }

    emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Pushing changes to remote'));
    
    try {
      // Validate that the directory exists and is a git repo
      final directory = Directory(localPath);
      if (!directory.existsSync()) {
        throw ActionFailedException('Local directory does not exist: $localPath', moduleId: action.id);
      }

      final isGitRepo = await GitDir.isGitDir(localPath);
      if (!isGitRepo) {
        throw ActionFailedException('Directory is not a git repository: $localPath', moduleId: action.id);
      }

      final gitDir = await GitDir.fromExisting(localPath);
      
      // Check if there are any commits to push
      final statusResult = await gitDir.runCommand(['status', '--porcelain=v1']);
      final hasUncommittedChanges = statusResult.stdout.trim().isNotEmpty;
      
      if (hasUncommittedChanges) {
        throw ActionFailedException('Cannot push: there are uncommitted changes. Please commit first.', moduleId: action.id);
      }

      // Check if there are commits ahead of remote
      final aheadResult = await gitDir.runCommand(['rev-list', '--count', 'HEAD', '^origin/$branch']);
      final commitsAhead = int.tryParse(aheadResult.stdout.trim()) ?? 0;

      if (commitsAhead == 0) {
        updateState({
          'operationSuccess': true,
          'operationOutput': 'No commits to push - repository is up to date',
          'operationError': null,
        });
        logger.info('No commits to push - repository is up to date');
        return;
      }

      // Perform the push with optional streaming
      if (streamOutput) {
        await runGit(['push', 'origin', branch], 
          echoOutput: true, 
          processWorkingDir: localPath);
      } else {
        await gitDir.runCommand(['push', 'origin', branch]);
      }

      // Validate the push was successful by checking status
      await gitDir.runCommand(['status', '--porcelain=v1']);

      updateState({
        'operationSuccess': true,
        'operationOutput': 'Successfully pushed $commitsAhead commit(s) to origin/$branch',
        'operationError': null,
      });

      logger.info('Successfully pushed $commitsAhead commit(s) to origin/$branch');
    } catch (e) {
      updateState({
        'operationSuccess': false,
        'operationOutput': null,
        'operationError': e.toString(),
      });
      throw ActionFailedException('Git push failed: ${e.toString()}', moduleId: action.id);
    }
  }

  /// Execute git commit operation using git package.
  Future<void> _executeCommit() async {
    if (commitMessage.isEmpty) {
      throw ActionFailedException('Commit message is required', moduleId: action.id);
    }
    if (localPath.isEmpty) {
      throw ActionFailedException('Local path is required for commit operation', moduleId: action.id);
    }

    emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Committing changes'));
    
    try {
      // Validate that the directory exists and is a git repo
      final directory = Directory(localPath);
      if (!directory.existsSync()) {
        throw ActionFailedException('Local directory does not exist: $localPath', moduleId: action.id);
      }

      final isGitRepo = await GitDir.isGitDir(localPath);
      if (!isGitRepo) {
        throw ActionFailedException('Directory is not a git repository: $localPath', moduleId: action.id);
      }

      final gitDir = await GitDir.fromExisting(localPath);
      
      // Check if there are any changes to commit
      final statusResult = await gitDir.runCommand(['status', '--porcelain=v1']);
      final hasChanges = statusResult.stdout.trim().isNotEmpty;
      
      if (!hasChanges) {
        updateState({
          'operationSuccess': true,
          'operationOutput': 'No changes to commit - working directory is clean',
          'operationError': null,
        });
        logger.info('No changes to commit - working directory is clean');
        return;
      }

      // Get the commit hash before commit
      final beforeCommit = await gitDir.runCommand(['rev-parse', 'HEAD']);
      final beforeHash = beforeCommit.stdout.trim();
      
      // Add all changes with optional streaming
      if (streamOutput) {
        await runGit(['add', '.'], 
          echoOutput: true, 
          processWorkingDir: localPath);
      } else {
        await gitDir.runCommand(['add', '.']);
      }
      
      // Commit changes with optional streaming
      if (streamOutput) {
        await runGit(['commit', '-m', commitMessage], 
          echoOutput: true, 
          processWorkingDir: localPath);
      } else {
        await gitDir.runCommand(['commit', '-m', commitMessage]);
      }
      
      // Get the commit hash after commit
      final afterCommit = await gitDir.runCommand(['rev-parse', 'HEAD']);
      final afterHash = afterCommit.stdout.trim();

      // Validate that a new commit was actually created
      if (beforeHash == afterHash) {
        throw ActionFailedException('Commit operation did not create a new commit', moduleId: action.id);
      }

      // Get the full commit hash and message for confirmation
      final logResult = await gitDir.runCommand(['log', '-1', '--format=%H %s']);
      final commitInfo = logResult.stdout.trim();

      updateState({
        'lastCommitHash': afterHash,
        'operationSuccess': true,
        'operationOutput': 'Successfully committed changes: $commitInfo',
        'operationError': null,
      });

      logger.info('Successfully committed changes: $commitInfo');
    } catch (e) {
      updateState({
        'operationSuccess': false,
        'operationOutput': null,
        'operationError': e.toString(),
      });
      throw ActionFailedException('Git commit failed: ${e.toString()}', moduleId: action.id);
    }
  }

  /// Rollback clone operation by removing the cloned directory.
  Future<void> _rollbackClone() async {
    // Get the local path from action properties during rollback
    final rollbackLocalPath = action.properties['local_path'] as String? ?? '';
    
    if (rollbackLocalPath.isNotEmpty) {
      try {
        final directory = Directory(rollbackLocalPath);
        if (directory.existsSync()) {
          await directory.delete(recursive: true);
          logger.info('Removed cloned directory: $rollbackLocalPath');
        } else {
          logger.info('Directory does not exist for rollback: $rollbackLocalPath');
        }
      } catch (e) {
        logger.warning('Failed to remove cloned directory: $e');
      }
    } else {
      logger.warning('No local path found for rollback in action properties');
    }
  }

  /// Rollback pull operation by resetting to previous commit.
  Future<void> _rollbackPull() async {
    // Get the local path from action properties during rollback
    final rollbackLocalPath = action.properties['local_path'] as String? ?? '';
    
    if (rollbackLocalPath.isNotEmpty) {
      try {
        final gitDir = await GitDir.fromExisting(rollbackLocalPath);
        // Reset to the commit before the pull
        await gitDir.runCommand(['reset', '--hard', 'HEAD~1']);
        logger.info('Rolled back pull operation for: $rollbackLocalPath');
      } catch (e) {
        logger.warning('Failed to rollback pull operation: $e');
      }
    } else {
      logger.warning('No local path found for pull rollback in action properties');
    }
  }

  /// Rollback commit operation by resetting to previous commit.
  Future<void> _rollbackCommit() async {
    if (lastCommitHash != null && localPath.isNotEmpty) {
      try {
        final gitDir = await GitDir.fromExisting(localPath);
        await gitDir.runCommand(['reset', '--hard', 'HEAD~1']);
        logger.info('Rolled back last commit');
      } catch (e) {
        logger.warning('Failed to rollback commit: $e');
      }
    }
  }
}