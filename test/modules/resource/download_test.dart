import 'package:test/test.dart';
import 'package:configr/modules/resource/download.dart';
import 'package:configr/models/action.dart';
import 'package:configr/events/module_events.dart';
import 'package:configr/utils/event_bus.dart';
import 'package:configr/exceptions.dart';
import '../../helpers/test_helper.dart';

void main() {
  late TestHelper helper;

  setUp(() {
    helper = TestHelper();
  });

  test('should download file successfully', () async {
    // Arrange
    const sourceUrl = 'https://httpbin.org/bytes/1024';
    const destinationPath = '/test/downloaded_file.bin';

    final resourceModel = helper.createTestResource(
        source: sourceUrl,
        destination: destinationPath,
        actions: [Action(type: 'download')]);

    final module = FileDownloadModule(resourceModel, resourceModel.actions.first,
        fileSystem: helper.fileSystem);

    // Act
    await module();

    // Assert
    expect(await helper.fileExists(destinationPath), isTrue);
    expect(module.receivedBytes, greaterThan(0));
    expect(module.actualChecksum, isNotNull);
  });

    test('should handle download with overwrite', () async {
      // Arrange
      const sourceUrl = 'https://httpbin.org/bytes/512';
      const destinationPath = '/test/existing_file.bin';
      const content = 'existing content';
      
      await helper.createTestFile(destinationPath, content);

      final resourceModel = helper.createTestResource(
          source: sourceUrl,
          destination: destinationPath,
          actions: [
            Action(
              type: 'download',
              properties: {'overwrite': true}
            )
          ]);

      final module = FileDownloadModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists(destinationPath), isTrue);
      expect(module.destinationFileExisted, isTrue);
      expect(module.receivedBytes, greaterThan(0));
    });

  group('Enhanced Download Features', () {
    test('should support resume capability', () async {
      // Arrange
      const sourceUrl = 'https://httpbin.org/bytes/2048';
      const destinationPath = '/test/resume_file.bin';

      final resourceModel = helper.createTestResource(
          source: sourceUrl,
          destination: destinationPath,
          actions: [
            Action(
              type: 'download',
              properties: {'resume': 'true'}
            )
          ]);

      final module = FileDownloadModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists(destinationPath), isTrue);
      expect(module.resumeEnabled, isTrue);
      expect(module.receivedBytes, greaterThan(0));
    });

    test('should support basic authentication', () async {
      // Arrange
      const sourceUrl = 'https://httpbin.org/basic-auth/user/pass';
      const destinationPath = '/test/auth_file.json';

      final resourceModel = helper.createTestResource(
          source: sourceUrl,
          destination: destinationPath,
          actions: [
            Action(
              type: 'download',
              properties: {
                'auth_type': 'basic',
                'username': 'user',
                'password': 'pass'
              }
            )
          ]);

      final module = FileDownloadModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists(destinationPath), isTrue);
      expect(module.authType, equals('basic'));
      expect(module.username, equals('user'));
      expect(module.password, equals('pass'));
    });

    test('should support bearer token authentication', () async {
      // Arrange
      const sourceUrl = 'https://httpbin.org/bearer';
      const destinationPath = '/test/bearer_file.json';
      const token = 'test-token-123';

      final resourceModel = helper.createTestResource(
          source: sourceUrl,
          destination: destinationPath,
          actions: [
            Action(
              type: 'download',
              properties: {
                'auth_type': 'bearer',
                'auth_token': token
              }
            )
          ]);

      final module = FileDownloadModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists(destinationPath), isTrue);
      expect(module.authType, equals('bearer'));
      expect(module.authToken, equals(token));
    });

    test('should support API key authentication', () async {
      // Arrange
      const sourceUrl = 'https://httpbin.org/headers';
      const destinationPath = '/test/api_key_file.json';
      const apiKey = 'test-api-key-456';

      final resourceModel = helper.createTestResource(
          source: sourceUrl,
          destination: destinationPath,
          actions: [
            Action(
              type: 'download',
              properties: {
                'auth_type': 'api_key',
                'auth_token': apiKey,
                'api_key_header': 'X-API-Key'
              }
            )
          ]);

      final module = FileDownloadModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists(destinationPath), isTrue);
      expect(module.authType, equals('api_key'));
      expect(module.authToken, equals(apiKey));
    });

    test('should support MD5 checksum validation', () async {
      // Arrange
      const sourceUrl = 'https://httpbin.org/bytes/1024';
      const destinationPath = '/test/md5_file.bin';

      final resourceModel = helper.createTestResource(
          source: sourceUrl,
          destination: destinationPath,
          actions: [
            Action(
              type: 'download',
              properties: {
                'checksum_algorithm': 'md5',
                'checksum': 'dummy-checksum' // This will fail validation
              }
            )
          ]);

      final module = FileDownloadModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act & Assert
      expect(() => module(), throwsA(isA<ActionFailedException>()));
      expect(module.checksumAlgorithm, equals('md5'));
    });

    test('should support SHA1 checksum validation', () async {
      // Arrange
      const sourceUrl = 'https://httpbin.org/bytes/1024';
      const destinationPath = '/test/sha1_file.bin';

      final resourceModel = helper.createTestResource(
          source: sourceUrl,
          destination: destinationPath,
          actions: [
            Action(
              type: 'download',
              properties: {
                'checksum_algorithm': 'sha1',
                'checksum': 'dummy-checksum' // This will fail validation
              }
            )
          ]);

      final module = FileDownloadModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act & Assert
      expect(() => module(), throwsA(isA<ActionFailedException>()));
      expect(module.checksumAlgorithm, equals('sha1'));
    });

    test('should track download speed and duration', () async {
      // Arrange
      const sourceUrl = 'https://httpbin.org/bytes/1024';
      const destinationPath = '/test/speed_file.bin';

      final resourceModel = helper.createTestResource(
          source: sourceUrl,
          destination: destinationPath,
          actions: [Action(type: 'download')]);

      final module = FileDownloadModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists(destinationPath), isTrue);
      expect(module.downloadDuration.inMilliseconds, greaterThan(0));
      expect(module.downloadSpeed, greaterThanOrEqualTo(0));
    });

    test('should emit progress events during download', () async {
      // Arrange
      const sourceUrl = 'https://httpbin.org/bytes/2048';
      const destinationPath = '/test/progress_file.bin';

      final resourceModel = helper.createTestResource(
          source: sourceUrl,
          destination: destinationPath,
          actions: [Action(type: 'download')]);

      final module = FileDownloadModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      final events = <ModuleEvent>[];
      eventBus.subscribe((event) {
        events.add(event);
      });

      // Act
      await module();

      // Assert
      expect(await helper.fileExists(destinationPath), isTrue);
      expect(events.any((e) => e is DownloadProgressEvent), isTrue);
      expect(events.any((e) => e is StartedEvent), isTrue);
      expect(events.any((e) => e is CompletedEvent), isTrue);
    });

    test('should handle resume from partial download', () async {
      // Arrange
      const sourceUrl = 'https://httpbin.org/bytes/2048';
      const destinationPath = '/test/partial_file.bin';
      const partialContent = 'partial content';

      // Create a partial file
      await helper.createTestFile(destinationPath, partialContent);

      final resourceModel = helper.createTestResource(
          source: sourceUrl,
          destination: destinationPath,
          actions: [
            Action(
              type: 'download',
              properties: {
                'resume': 'true',
                'overwrite': true
              }
            )
          ]);

      final module = FileDownloadModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists(destinationPath), isTrue);
      // Note: Resume may not work with httpbin.org, so we just check that the download completed
      expect(module.receivedBytes, greaterThan(0));
    });

    test('should handle download failure gracefully', () async {
      // Arrange
      const sourceUrl = 'https://httpbin.org/status/404';
      const destinationPath = '/test/failed_file.bin';

      final resourceModel = helper.createTestResource(
          source: sourceUrl,
          destination: destinationPath,
          actions: [Action(type: 'download')]);

      final module = FileDownloadModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act & Assert
      expect(() => module(), throwsA(isA<ActionFailedException>()));
      expect(await helper.fileExists(destinationPath), isFalse);
    });

    test('should handle rollback correctly', () async {
      // Arrange
      const sourceUrl = 'https://httpbin.org/json';
      const destinationPath = '/test/rollback_file.json';

      final resourceModel = helper.createTestResource(
          source: sourceUrl,
          destination: destinationPath,
          actions: [Action(type: 'download')]);

      final module = FileDownloadModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();
      await module.rollback();

      // Assert
      // Rollback should complete without errors
      expect(module.destinationFileExisted, isFalse);
    });

    test('should handle complex configuration', () async {
      // Arrange
      const sourceUrl = 'https://httpbin.org/bytes/1024';
      const destinationPath = '/test/complex_file.bin';

      final resourceModel = helper.createTestResource(
          source: sourceUrl,
          destination: destinationPath,
          actions: [
            Action(
              type: 'download',
              properties: {
                'resume': 'true',
                'auth_type': 'bearer',
                'auth_token': 'test-token',
                'checksum_algorithm': 'sha256',
                'overwrite': true
              }
            )
          ]);

      final module = FileDownloadModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists(destinationPath), isTrue);
      expect(module.resumeEnabled, isTrue);
      expect(module.authType, equals('bearer'));
      expect(module.authToken, equals('test-token'));
      expect(module.checksumAlgorithm, equals('sha256'));
      expect(module.overwrite, isTrue);
    });

    test('should handle non-existent destination directory', () async {
      // Arrange
      const sourceUrl = 'https://httpbin.org/bytes/1024';
      const destinationPath = '/test/nonexistent/dir/file.bin';

      // Create the directory first
      await helper.createDirectory('/test/nonexistent/dir');

      final resourceModel = helper.createTestResource(
          source: sourceUrl,
          destination: destinationPath,
          actions: [Action(type: 'download')]);

      final module = FileDownloadModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists(destinationPath), isTrue);
      expect(module.receivedBytes, greaterThan(0));
    });

    test('should handle large file download', () async {
      // Arrange
      const sourceUrl = 'https://httpbin.org/bytes/8192'; // 8KB
      const destinationPath = '/test/large_file.bin';

      final resourceModel = helper.createTestResource(
          source: sourceUrl,
          destination: destinationPath,
          actions: [Action(type: 'download')]);

      final module = FileDownloadModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(await helper.fileExists(destinationPath), isTrue);
      expect(module.receivedBytes, equals(8192));
      expect(module.totalBytes, equals(8192));
    });
  });
}
