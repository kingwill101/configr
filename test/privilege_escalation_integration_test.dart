import 'package:test/test.dart';
import 'package:configr/models/action.dart';
import 'package:configr/models/file_model.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/privellage_escallation.dart';

void main() {
  group('Privilege Escalation Integration Tests', () {
    late PrivilegeLock lock;

    setUp(() {
      PrivilegeLock.reset();
      lock = PrivilegeLock.instance;
    });

    tearDown(() {
      PrivilegeLock.reset();
    });

    test('Complete privilege escalation workflow', () {
      // Test the complete workflow from resource configuration to privilege escalation
      
      // 1. Create a resource that requires root privileges
      final privilegedResource = ResourceModel(
        id: 'privileged-resource',
        source: '/tmp/source.txt',
        destination: '/etc/test.txt',
        actions: [],
        properties: {'require_root': true},
      );

      // 2. Create actions with different privilege requirements
      final privilegedAction = Action(
        id: 'privileged-action',
        type: 'copy',
        properties: {}, // Inherits from resource
        parent: privilegedResource.properties,
      );

      final unprivilegedAction = Action(
        id: 'unprivileged-action',
        type: 'permissions',
        properties: {'require_root': false}, // Override resource setting
        parent: privilegedResource.properties,
      );

      // 3. Create modules and test privilege detection
      final privilegedModule = TestResourceModule(privilegedResource, privilegedAction);
      final unprivilegedModule = TestResourceModule(privilegedResource, unprivilegedAction);

      // 4. Verify privilege detection
      expect(privilegedModule.shouldUsePrivilegeEscalation(), isTrue,
          reason: 'Action should inherit require_root=true from resource');
      expect(unprivilegedModule.shouldUsePrivilegeEscalation(), isFalse,
          reason: 'Action should override resource require_root=true to false');

      // 5. Test privilege lock workflow
      expect(lock.isActive, isFalse);
      
      // Simulate privilege escalation
      lock.acquire();
      expect(lock.isActive, isTrue);
      expect(lock.lastUsed, isNotNull);

      // Simulate multiple operations using the same privilege lock
      lock.acquire(); // Should update lastUsed, not create new lock
      expect(lock.isActive, isTrue);

      // Simulate privilege release
      lock.release();
      expect(lock.isActive, isFalse);
      expect(lock.lastUsed, isNull);
    });

    test('Mixed privilege requirements in same resource', () {
      // Test a resource with mixed privilege requirements
      final mixedResource = ResourceModel(
        id: 'mixed-resource',
        source: '/tmp/source.txt',
        destination: '/etc/test.txt',
        actions: [],
        properties: {'require_root': true}, // Default to privileged
      );

      // Create actions with different privilege overrides
      final actions = [
        Action(id: 'copy', type: 'copy', properties: {}, parent: mixedResource.properties), // Inherits true
        Action(id: 'permissions', type: 'permissions', properties: {'require_root': false}, parent: mixedResource.properties), // Override to false
        Action(id: 'backup', type: 'backup', properties: {'require_root': true}, parent: mixedResource.properties), // Override to true
        Action(id: 'validate', type: 'validate', properties: {}, parent: mixedResource.properties), // Inherits true
      ];

      final modules = actions.map((action) => TestResourceModule(mixedResource, action)).toList();

      // Verify each action has correct privilege requirement
      expect(modules[0].shouldUsePrivilegeEscalation(), isTrue, reason: 'copy should inherit true');
      expect(modules[1].shouldUsePrivilegeEscalation(), isFalse, reason: 'permissions should override to false');
      expect(modules[2].shouldUsePrivilegeEscalation(), isTrue, reason: 'backup should override to true');
      expect(modules[3].shouldUsePrivilegeEscalation(), isTrue, reason: 'validate should inherit true');
    });

    test('Privilege lock timeout behavior', () async {
      // Test that privilege lock times out correctly
      lock.acquire();
      expect(lock.isActive, isTrue);
      
      final initialTime = lock.timeUntilTimeout;
      expect(initialTime, isNotNull);
      expect(initialTime!.inMinutes, greaterThanOrEqualTo(14));
      expect(initialTime.inMinutes, lessThanOrEqualTo(15));

      // Simulate time passing
      await Future.delayed(Duration(milliseconds: 50));
      
      final laterTime = lock.timeUntilTimeout;
      expect(laterTime, isNotNull);
      expect(laterTime!.inSeconds, lessThanOrEqualTo(initialTime.inSeconds));
    });

    test('Resource properties inheritance chain', () {
      // Test complex inheritance scenarios
      final baseResource = ResourceModel(
        id: 'base-resource',
        source: '/tmp/source.txt',
        destination: '/etc/test.txt',
        actions: [],
        properties: {
          'require_root': true,
          'custom_prop': 'base_value',
          'shared_prop': 'shared_value',
        },
      );

      final actionWithOverrides = Action(
        id: 'action-with-overrides',
        type: 'copy',
        properties: {
          'require_root': false, // Override privilege requirement
          'custom_prop': 'action_value', // Override custom property
          'action_only_prop': 'action_only_value', // Add new property
        },
        parent: baseResource.properties,
      );

      final module = TestResourceModule(baseResource, actionWithOverrides);

      // Test privilege inheritance
      expect(module.shouldUsePrivilegeEscalation(), isFalse,
          reason: 'Action should override resource require_root=true to false');

      // Test property access
      expect(baseResource.properties['require_root'], isTrue);
      expect(baseResource.properties['custom_prop'], equals('base_value'));
      expect(baseResource.properties['shared_prop'], equals('shared_value'));

      expect(actionWithOverrides.properties['require_root'], isFalse);
      expect(actionWithOverrides.properties['custom_prop'], equals('action_value'));
      expect(actionWithOverrides.properties['action_only_prop'], equals('action_only_value'));
    });

    test('Edge cases and error handling', () {
      // Test edge cases
      final resourceWithNull = ResourceModel(
        id: 'resource-with-null',
        source: '/tmp/source.txt',
        destination: '/tmp/test.txt',
        actions: [],
        properties: {'require_root': null},
      );

      final actionWithNull = Action(
        id: 'action-with-null',
        type: 'copy',
        properties: {'require_root': null},
        parent: resourceWithNull.properties,
      );

      final moduleWithNull = TestResourceModule(resourceWithNull, actionWithNull);
      expect(moduleWithNull.shouldUsePrivilegeEscalation(), isFalse,
          reason: 'Null require_root should default to false');

      // Test with undefined properties
      final resourceWithUndefined = ResourceModel(
        id: 'resource-undefined',
        source: '/tmp/source.txt',
        destination: '/tmp/test.txt',
        actions: [],
        properties: {'other_prop': 'value'},
      );

      final actionWithUndefined = Action(
        id: 'action-undefined',
        type: 'copy',
        properties: {'other_prop': 'value'},
        parent: resourceWithUndefined.properties,
      );

      final moduleWithUndefined = TestResourceModule(resourceWithUndefined, actionWithUndefined);
      expect(moduleWithUndefined.shouldUsePrivilegeEscalation(), isFalse,
          reason: 'Undefined require_root should default to false');
    });

    test('Singleton behavior across multiple resources', () {
      // Test that privilege lock singleton works across multiple resources
      final resource1 = ResourceModel(
        id: 'resource-1',
        source: '/tmp/source1.txt',
        destination: '/etc/test1.txt',
        actions: [],
        properties: {'require_root': true},
      );

      final resource2 = ResourceModel(
        id: 'resource-2',
        source: '/tmp/source2.txt',
        destination: '/etc/test2.txt',
        actions: [],
        properties: {'require_root': true},
      );

      final action1 = Action(id: 'action-1', type: 'copy', properties: {}, parent: resource1.properties);
      final action2 = Action(id: 'action-2', type: 'copy', properties: {}, parent: resource2.properties);

      final module1 = TestResourceModule(resource1, action1);
      final module2 = TestResourceModule(resource2, action2);

      // Both should require privileges
      expect(module1.shouldUsePrivilegeEscalation(), isTrue);
      expect(module2.shouldUsePrivilegeEscalation(), isTrue);

      // Both should use the same privilege lock instance
      final lock1 = PrivilegeLock.instance;
      final lock2 = PrivilegeLock.instance;
      expect(identical(lock1, lock2), isTrue);

      // Acquiring lock should affect both modules
      lock1.acquire();
      expect(lock1.isActive, isTrue);
      expect(lock2.isActive, isTrue);
    });
  });
}

/// Test implementation of ResourceModule for integration testing
class TestResourceModule extends ResourceModule {
  TestResourceModule(ResourceModel file, Action action) 
      : super(file, action, allowedActions: const ['copy', 'permissions', 'backup', 'validate']);
  
  @override
  Future<void> execute() async {
    // Test implementation - not used in these tests
  }
}
