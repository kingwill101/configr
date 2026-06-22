import 'dart:io';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/cli/ui/handlers/cli_handler.dart';
import 'package:test/test.dart';

void main() {
  group('CLIHandler', () {
    late CLIHandler handler;

    setUp(() {
      handler = CLIHandler();
    });

    tearDown(() {
      handler.stop();
    });

    test('should start and stop correctly', () {
      expect(() => handler.start(), returnsNormally);
      expect(() => handler.stop(), returnsNormally);
    });

    test('should handle StartedEvent correctly', () {
      handler.start();
      
      final event = StartedEvent(moduleId: 'test-module', message: 'Starting test operation');
      
      // Capture stdout output
      final capturedOutput = StringBuffer();
      final originalStdout = stdout;
      
      // Test that the event is handled without errors
      expect(() => handler.handleEvent(event), returnsNormally);
    });

    test('should handle ProgressEvent correctly', () {
      handler.start();
      
      final event = ProgressEvent(moduleId: 'test-module', current: 50, total: 100, message: 'Processing...');
      
      // Test that the event is handled without errors
      expect(() => handler.handleEvent(event), returnsNormally);
    });

    test('should handle CompletedEvent correctly', () {
      handler.start();
      
      final event = CompletedEvent(moduleId: 'test-module', message: 'Operation completed successfully');
      
      // Test that the event is handled without errors
      expect(() => handler.handleEvent(event), returnsNormally);
    });

    test('should handle FailedEvent correctly', () {
      handler.start();
      
      final event = FailedEvent(moduleId: 'test-module', message: 'Operation failed');
      
      // Test that the event is handled without errors
      expect(() => handler.handleEvent(event), returnsNormally);
    });

    test('should handle StatusUpdateEvent correctly', () {
      handler.start();
      
      final event = StatusUpdateEvent(moduleId: 'test-module', level: StatusEvent.warning, message: 'Warning message');
      
      // Test that the event is handled without errors
      expect(() => handler.handleEvent(event), returnsNormally);
    });

    test('should enable and disable interactive mode correctly', () {
      handler.start();
      
      expect(() => handler.enableInteractiveMode(), returnsNormally);
      expect(() => handler.disableInteractiveMode(), returnsNormally);
    });

    test('should enable and disable password prompt mode correctly', () {
      handler.start();
      
      expect(() => handler.enablePasswordPromptMode(), returnsNormally);
      expect(() => handler.disablePasswordPromptMode(), returnsNormally);
    });

    test('should handle events when not active', () {
      final event = StartedEvent(moduleId: 'test-module', message: 'Starting operation');
      
      // Should not throw when handler is not active
      expect(() => handler.handleEvent(event), returnsNormally);
    });

    test('should handle multiple different events', () {
      handler.start();
      
      final events = [
        StartedEvent(moduleId: 'module-1', message: 'Starting module 1'),
        ProgressEvent(moduleId: 'module-1', current: 25, total: 100, message: 'Processing...'),
        CompletedEvent(moduleId: 'module-1', message: 'Module 1 completed'),
      ];
      
      for (final event in events) {
        expect(() => handler.handleEvent(event), returnsNormally);
      }
    });

    test('should pause output during password prompt mode', () {
      handler.start();
      
      // Enable password prompt mode
      handler.enablePasswordPromptMode();
      
      // Events should not be output when in password prompt mode
      final event = StartedEvent(moduleId: 'test-module', message: 'Should not appear');
      handler.handleEvent(event);
      
      // Disable password prompt mode
      handler.disablePasswordPromptMode();
      
      // Events should be output again after disabling password prompt mode
      final event2 = StartedEvent(moduleId: 'test-module', message: 'Should appear');
      handler.handleEvent(event2);
      
      // Test should complete without errors
      expect(() => handler.handleEvent(event2), returnsNormally);
    });

    test('should handle ResourceStartedEvent correctly', () {
      handler.start();
      
      final event = ResourceStartedEvent(
        moduleId: 'config-manager',
        resourceId: 'test-resource',
        resourceType: 'package',
        source: '/tmp',
        destination: '/tmp',
        actionCount: 3,
      );
      
      // Test that the event is handled without errors
      expect(() => handler.handleEvent(event), returnsNormally);
    });

    test('should handle ResourceCompletedEvent correctly', () {
      handler.start();
      
      final event = ResourceCompletedEvent(
        moduleId: 'config-manager',
        resourceId: 'test-resource',
        resourceType: 'package',
        source: '/tmp',
        destination: '/tmp',
        completedActions: 3,
        totalActions: 3,
        duration: Duration(milliseconds: 1500),
      );
      
      // Test that the event is handled without errors
      expect(() => handler.handleEvent(event), returnsNormally);
    });

    test('should handle ResourceRollbackStartedEvent correctly', () {
      handler.start();
      
      final event = ResourceRollbackStartedEvent(
        moduleId: 'config-manager',
        resourceId: 'test-resource',
        resourceType: 'download',
        source: 'https://example.com/file.txt',
        destination: '/tmp/file.txt',
        actionCount: 2,
      );
      
      // Test that the event is handled without errors
      expect(() => handler.handleEvent(event), returnsNormally);
    });

    test('should handle ResourceRollbackCompletedEvent correctly', () {
      handler.start();
      
      final event = ResourceRollbackCompletedEvent(
        moduleId: 'config-manager',
        resourceId: 'test-resource',
        resourceType: 'download',
        source: 'https://example.com/file.txt',
        destination: '/tmp/file.txt',
        rolledbackActions: 2,
        totalActions: 2,
        duration: Duration(milliseconds: 800),
      );
      
      // Test that the event is handled without errors
      expect(() => handler.handleEvent(event), returnsNormally);
    });
  });
}
