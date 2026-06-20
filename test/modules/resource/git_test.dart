import 'package:configr/exceptions.dart';
import 'package:configr/models/action.dart';
import 'package:configr/models/file_model.dart';
import 'package:configr/modules/resource/git.dart';
import 'package:test/test.dart';
import 'dart:io';

void main() {
  group('FileGitModule', () {
    late FileGitModule gitModule;
    late Action action;
    late ResourceModel file;

    setUp(() {
      action = Action(
        id: 'test-git-action',
        type: 'git',
        properties: {},
      );
      file = ResourceModel(
        id: 'test-file',
        source: '/tmp/test-repo',
        destination: '/tmp/test-repo',
        type: 'directory',
        actions: [action],
      );
      gitModule = FileGitModule(file, action);
    });

    group('Initialization', () {
      test('should initialize with default values', () {
        expect(gitModule.repositoryUrl, isEmpty);
        expect(gitModule.localPath, isEmpty);
        expect(gitModule.branch, equals('main'));
        expect(gitModule.commitMessage, isEmpty);
        expect(gitModule.operationSuccess, isFalse);
        expect(gitModule.lastCommitHash, isNull);
        expect(gitModule.operationDuration.inMilliseconds, equals(0));
        expect(gitModule.operationOutput, isNull);
        expect(gitModule.operationError, isNull);
      });

      test('should update state with configuration', () {
        final config = {
          'repository_url': 'https://github.com/test/repo.git',
          'local_path': '/tmp/cloned-repo',
          'branch': 'develop',
          'commit_message': 'Test commit',
        };

        action.properties = config;
        gitModule = FileGitModule(file, action);
        
        // Manually update state to simulate what happens in execute()
        gitModule.updateState({
          'repositoryUrl': 'https://github.com/test/repo.git',
          'localPath': '/tmp/cloned-repo',
          'branch': 'develop',
          'commitMessage': 'Test commit',
        });

        expect(gitModule.repositoryUrl, equals('https://github.com/test/repo.git'));
        expect(gitModule.localPath, equals('/tmp/cloned-repo'));
        expect(gitModule.branch, equals('develop'));
        expect(gitModule.commitMessage, equals('Test commit'));
      });
    });

    group('Clone Operation', () {
      test('should validate required parameters for clone', () async {
        action.properties = {
          'operation': 'clone',
          'local_path': '/tmp/test-repo',
        };

        gitModule = FileGitModule(file, action);
        
        expect(
          () => gitModule.execute(),
          throwsA(isA<ActionFailedException>().having(
            (e) => e.toString(),
            'message',
            contains('Repository URL is required'),
          )),
        );
      });

      test('should validate local path for clone', () async {
        action.properties = {
          'operation': 'clone',
          'repository_url': 'https://github.com/test/repo.git',
        };

        gitModule = FileGitModule(file, action);
        
        expect(
          () => gitModule.execute(),
          throwsA(isA<ActionFailedException>().having(
            (e) => e.toString(),
            'message',
            contains('Local path is required'),
          )),
        );
      });
    });

    group('Pull Operation', () {
      test('should validate local directory exists for pull', () async {
        action.properties = {
          'operation': 'pull',
          'local_path': '/nonexistent/directory',
        };

        gitModule = FileGitModule(file, action);
        
        expect(
          () => gitModule.execute(),
          throwsA(isA<ActionFailedException>().having(
            (e) => e.toString(),
            'message',
            contains('Local directory does not exist'),
          )),
        );
      });

      test('should validate directory is git repo for pull', () async {
        // Create a temporary directory that's not a git repo
        final tempDir = Directory.systemTemp.createTempSync('configr_test_');
        // Ensure the directory exists by creating a file in it
        File('${tempDir.path}/test.txt').createSync();
        
        action.properties = {
          'operation': 'pull',
          'local_path': tempDir.path,
        };

        gitModule = FileGitModule(file, action);
        
        try {
          expect(
            () => gitModule.execute(),
            throwsA(isA<ActionFailedException>()),
          );
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      });
    });

    group('Push Operation', () {
      test('should validate local directory exists for push', () async {
        action.properties = {
          'operation': 'push',
          'local_path': '/nonexistent/directory',
        };

        gitModule = FileGitModule(file, action);
        
        expect(
          () => gitModule.execute(),
          throwsA(isA<ActionFailedException>().having(
            (e) => e.toString(),
            'message',
            contains('Local directory does not exist'),
          )),
        );
      });

      test('should validate directory is git repo for push', () async {
        // Create a temporary directory that's not a git repo
        final tempDir = Directory.systemTemp.createTempSync('configr_test_');
        // Ensure the directory exists by creating a file in it
        File('${tempDir.path}/test.txt').createSync();
        
        action.properties = {
          'operation': 'push',
          'local_path': tempDir.path,
        };

        gitModule = FileGitModule(file, action);
        
        try {
          expect(
            () => gitModule.execute(),
            throwsA(isA<ActionFailedException>()),
          );
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      });
    });

    group('Commit Operation', () {
      test('should validate commit message', () async {
        action.properties = {
          'operation': 'commit',
          'local_path': '/tmp/test-repo',
        };

        gitModule = FileGitModule(file, action);
        
        expect(
          () => gitModule.execute(),
          throwsA(isA<ActionFailedException>().having(
            (e) => e.toString(),
            'message',
            contains('Commit message is required'),
          )),
        );
      });

      test('should validate local directory exists for commit', () async {
        action.properties = {
          'operation': 'commit',
          'local_path': '/nonexistent/directory',
          'commit_message': 'Test commit',
        };

        gitModule = FileGitModule(file, action);
        
        expect(
          () => gitModule.execute(),
          throwsA(isA<ActionFailedException>().having(
            (e) => e.toString(),
            'message',
            contains('Local directory does not exist'),
          )),
        );
      });

      test('should validate directory is git repo for commit', () async {
        // Create a temporary directory that's not a git repo
        final tempDir = Directory.systemTemp.createTempSync('configr_test_');
        // Ensure the directory exists by creating a file in it
        File('${tempDir.path}/test.txt').createSync();
        
        action.properties = {
          'operation': 'commit',
          'local_path': tempDir.path,
          'commit_message': 'Test commit',
        };

        gitModule = FileGitModule(file, action);
        
        try {
          expect(
            () => gitModule.execute(),
            throwsA(isA<ActionFailedException>()),
          );
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      });
    });

    group('Unknown Operation', () {
      test('should throw exception for unknown operation', () async {
        action.properties = {
          'operation': 'unknown',
        };

        gitModule = FileGitModule(file, action);
        
        expect(
          () => gitModule.execute(),
          throwsA(isA<ActionFailedException>().having(
            (e) => e.toString(),
            'message',
            contains('Unknown git operation: unknown'),
          )),
        );
      });
    });

    group('Rollback', () {
      test('should handle rollback for clone operation', () async {
        action.properties = {
          'operation': 'clone',
          'repository_url': 'https://github.com/test/repo.git',
          'local_path': '/tmp/test-repo',
        };

        gitModule = FileGitModule(file, action);
        gitModule.updateState({'operationSuccess': true});

        // Should not throw exception
        expect(() => gitModule.rollback(), returnsNormally);
      });

      test('should handle rollback for commit operation', () async {
        action.properties = {
          'operation': 'commit',
          'local_path': '/tmp/test-repo',
        };

        gitModule = FileGitModule(file, action);
        gitModule.updateState({'lastCommitHash': 'abc123'});

        // Should not throw exception
        expect(() => gitModule.rollback(), returnsNormally);
      });

      test('should handle rollback for push operation', () async {
        action.properties = {
          'operation': 'push',
          'local_path': '/tmp/test-repo',
        };

        gitModule = FileGitModule(file, action);

        // Should not throw exception
        expect(() => gitModule.rollback(), returnsNormally);
      });

      test('should handle rollback for unknown operation', () async {
        action.properties = {
          'operation': 'unknown',
        };

        gitModule = FileGitModule(file, action);

        // Should not throw exception
        expect(() => gitModule.rollback(), returnsNormally);
      });
    });

    group('State Management', () {
      test('should update state correctly', () {
        gitModule.updateState({
          'repositoryUrl': 'https://github.com/test/repo.git',
          'operationSuccess': true,
          'lastCommitHash': 'abc123',
        });

        expect(gitModule.repositoryUrl, equals('https://github.com/test/repo.git'));
        expect(gitModule.operationSuccess, isTrue);
        expect(gitModule.lastCommitHash, equals('abc123'));
      });

      test('should preserve existing state when updating', () {
        gitModule.updateState({'repositoryUrl': 'https://github.com/test/repo.git'});
        gitModule.updateState({'operationSuccess': true});

        expect(gitModule.repositoryUrl, equals('https://github.com/test/repo.git'));
        expect(gitModule.operationSuccess, isTrue);
      });
    });

    group('Operation Duration', () {
      test('should track operation duration', () {
        gitModule.updateState({'operationDuration': 1500});
        expect(gitModule.operationDuration.inMilliseconds, equals(1500));
      });

      test('should default operation duration to zero', () {
        expect(gitModule.operationDuration.inMilliseconds, equals(0));
      });
    });

    group('Operation Output', () {
      test('should track operation output', () {
        gitModule.updateState({'operationOutput': 'Git operation successful'});
        expect(gitModule.operationOutput, equals('Git operation successful'));
      });

      test('should track operation error', () {
        gitModule.updateState({'operationError': 'Git operation failed'});
        expect(gitModule.operationError, equals('Git operation failed'));
      });
    });
  });
}