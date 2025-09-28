import 'package:test/test.dart';
import 'package:configr/modules/resource/execute.dart';
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

  test('should execute command successfully', () async {
    // Arrange
    final resourceModel = helper.createTestResource(
        source: '/test',
        destination: '/test',
        actions: [
          Action(
            type: 'execute',
            properties: {'command': 'echo "Hello World"'}
          )
        ]);

    final module = FileExecuteModule(resourceModel, resourceModel.actions.first,
        fileSystem: helper.fileSystem);

    // Act
    await module();

    // Assert
    expect(module.exitCode, equals(0));
    expect(module.executionDuration.inMilliseconds, greaterThan(0));
  });

  test('should handle command failure', () async {
    // Arrange
    final resourceModel = helper.createTestResource(
        source: '/test',
        destination: '/test',
        actions: [
          Action(
            type: 'execute',
            properties: {'command': 'exit 1'}
          )
        ]);

    final module = FileExecuteModule(resourceModel, resourceModel.actions.first,
        fileSystem: helper.fileSystem);

    // Act & Assert
    expect(() => module(), throwsA(isA<ActionFailedException>()));
  });

  group('Enhanced Execute Features', () {
    test('should support environment variables', () async {
      // Arrange
      final resourceModel = helper.createTestResource(
          source: '/test',
          destination: '/test',
          actions: [
            Action(
              type: 'execute',
              properties: {
                'command': 'echo \$TEST_VAR',
                'environment': {
                  'TEST_VAR': 'test_value'
                }
              }
            )
          ]);

      final module = FileExecuteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(module.exitCode, equals(0));
      expect(module.environment['TEST_VAR'], equals('test_value'));
    });

    test('should support custom working directory', () async {
      // Arrange
      final resourceModel = helper.createTestResource(
          source: '/test',
          destination: '/test',
          actions: [
            Action(
              type: 'execute',
              properties: {
                'command': 'pwd',
                'working_directory': '/tmp'
              }
            )
          ]);

      final module = FileExecuteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(module.exitCode, equals(0));
      expect(module.workingDirectory, equals('/tmp'));
    });

    test('should support timeout configuration', () async {
      // Arrange
      final resourceModel = helper.createTestResource(
          source: '/test',
          destination: '/test',
          actions: [
            Action(
              type: 'execute',
              properties: {
                'command': 'sleep 2',
                'timeout': 1
              }
            )
          ]);

      final module = FileExecuteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act & Assert
      expect(() => module(), throwsA(isA<ActionFailedException>()));
    });

    test('should support input to command', () async {
      // Arrange
      final resourceModel = helper.createTestResource(
          source: '/test',
          destination: '/test',
          actions: [
            Action(
              type: 'execute',
              properties: {
                'command': 'cat',
                'input': 'test input data'
              }
            )
          ]);

      final module = FileExecuteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(module.exitCode, equals(0));
      expect(module.input, equals('test input data'));
    });

    test('should support environment inheritance control', () async {
      // Arrange
      final resourceModel = helper.createTestResource(
          source: '/test',
          destination: '/test',
          actions: [
            Action(
              type: 'execute',
              properties: {
                'command': 'env | grep PATH',
                'inherit_environment': 'false',
                'environment': {
                  'CUSTOM_VAR': 'custom_value'
                }
              }
            )
          ]);

      final module = FileExecuteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(module.exitCode, equals(0));
      expect(module.inheritEnvironment, isFalse);
      expect(module.environment['CUSTOM_VAR'], equals('custom_value'));
    });

    test('should support output size limits', () async {
      // Arrange
      final resourceModel = helper.createTestResource(
          source: '/test',
          destination: '/test',
          actions: [
            Action(
              type: 'execute',
              properties: {
                'command': 'yes | head -1000',
                'max_output_size': 100
              }
            )
          ]);

      final module = FileExecuteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(module.exitCode, equals(0));
      expect(module.maxOutputSize, equals(100));
    });

    test('should track execution duration', () async {
      // Arrange
      final resourceModel = helper.createTestResource(
          source: '/test',
          destination: '/test',
          actions: [
            Action(
              type: 'execute',
              properties: {
                'command': 'sleep 1'
              }
            )
          ]);

      final module = FileExecuteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(module.exitCode, equals(0));
      expect(module.executionDuration.inMilliseconds, greaterThanOrEqualTo(1000));
    });

    test('should track process ID', () async {
      // Arrange
      final resourceModel = helper.createTestResource(
          source: '/test',
          destination: '/test',
          actions: [
            Action(
              type: 'execute',
              properties: {
                'command': 'echo "test"'
              }
            )
          ]);

      final module = FileExecuteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(module.exitCode, equals(0));
      expect(module.processId, greaterThan(0));
    });

    test('should emit progress events during execution', () async {
      // Arrange
      final resourceModel = helper.createTestResource(
          source: '/test',
          destination: '/test',
          actions: [
            Action(
              type: 'execute',
              properties: {
                'command': 'sleep 1 && echo "done"'
              }
            )
          ]);

      final module = FileExecuteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      final events = <ModuleEvent>[];
      eventBus.subscribe((event) {
        events.add(event);
      });

      // Act
      await module();

      // Assert
      expect(module.exitCode, equals(0));
      expect(events.any((e) => e is StartedEvent), isTrue);
      expect(events.any((e) => e is CompletedEvent), isTrue);
    });

    test('should handle complex configuration', () async {
      // Arrange
      final resourceModel = helper.createTestResource(
          source: '/test',
          destination: '/test',
          actions: [
            Action(
              type: 'execute',
              properties: {
                'command': 'echo \$CUSTOM_VAR',
                'environment': {
                  'CUSTOM_VAR': 'complex_test'
                },
                'working_directory': '/tmp',
                'timeout': 30,
                'input': 'test input',
                'inherit_environment': 'true',
                'max_output_size': 1024
              }
            )
          ]);

      final module = FileExecuteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(module.exitCode, equals(0));
      expect(module.environment['CUSTOM_VAR'], equals('complex_test'));
      expect(module.workingDirectory, equals('/tmp'));
      expect(module.timeout.inSeconds, equals(30));
      expect(module.input, equals('test input'));
      expect(module.inheritEnvironment, isTrue);
      expect(module.maxOutputSize, equals(1024));
    });

    test('should handle timeout with process killing', () async {
      // Arrange
      final resourceModel = helper.createTestResource(
          source: '/test',
          destination: '/test',
          actions: [
            Action(
              type: 'execute',
              properties: {
                'command': 'sleep 10',
                'timeout': 1
              }
            )
          ]);

      final module = FileExecuteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act & Assert
      expect(() => module(), throwsA(isA<ActionFailedException>()));
    });

    test('should handle on_success condition', () async {
      // Arrange
      final resourceModel = helper.createTestResource(
          source: '/test',
          destination: '/test',
          actions: [
            Action(
              type: 'execute',
              properties: {
                'command': 'echo "test"',
                'on_success': 'true'
              }
            )
          ]);

      // Set action status to completed to trigger on_success behavior
      resourceModel.actions.first.status = 'completed';

      final module = FileExecuteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(module.onSuccess, isTrue);
    });

    test('should handle command with stderr output', () async {
      // Arrange
      final resourceModel = helper.createTestResource(
          source: '/test',
          destination: '/test',
          actions: [
            Action(
              type: 'execute',
              properties: {
                'command': 'echo "error" >&2'
              }
            )
          ]);

      final module = FileExecuteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(module.exitCode, equals(0));
    });

    test('should handle rollback gracefully', () async {
      // Arrange
      final resourceModel = helper.createTestResource(
          source: '/test',
          destination: '/test',
          actions: [
            Action(
              type: 'execute',
              properties: {
                'command': 'echo "test"'
              }
            )
          ]);

      final module = FileExecuteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();
      await module.rollback();

      // Assert
      expect(module.state['rollbackAttempted'], isTrue);
    });

    test('should handle large output with size limits', () async {
      // Arrange
      final resourceModel = helper.createTestResource(
          source: '/test',
          destination: '/test',
          actions: [
            Action(
              type: 'execute',
              properties: {
                'command': 'yes | head -10000',
                'max_output_size': 50
              }
            )
          ]);

      final module = FileExecuteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(module.exitCode, equals(0));
    });

    test('should handle environment variable parsing', () async {
      // Arrange
      final resourceModel = helper.createTestResource(
          source: '/test',
          destination: '/test',
          actions: [
            Action(
              type: 'execute',
              properties: {
                'command': 'echo \$VAR1 \$VAR2',
                'environment': {
                  'VAR1': 'value1',
                  'VAR2': 'value2'
                }
              }
            )
          ]);

      final module = FileExecuteModule(resourceModel, resourceModel.actions.first,
          fileSystem: helper.fileSystem);

      // Act
      await module();

      // Assert
      expect(module.exitCode, equals(0));
      expect(module.environment['VAR1'], equals('value1'));
      expect(module.environment['VAR2'], equals('value2'));
    });
  });
}
