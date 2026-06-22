import 'package:test/test.dart';
import 'package:configr/configr.dart';

void main() {
  group('Privilege Inheritance Tests', () {
    late ResourceModel resourceWithRoot;
    late ResourceModel resourceWithoutRoot;
    late Action actionWithOverride;
    late Action actionWithoutOverride;

    setUp(() {
      // Create a resource with require_root = true
      resourceWithRoot = ResourceModel(
        id: 'test-resource-with-root',
        source: '/tmp/source.txt',
        destination: '/etc/test.txt',
        actions: [],
        properties: {'require_root': true},
      );

      // Create a resource without require_root (defaults to false)
      resourceWithoutRoot = ResourceModel(
        id: 'test-resource-without-root',
        source: '/tmp/source.txt',
        destination: '/tmp/test.txt',
        actions: [],
        properties: {},
      );

      // Create an action that overrides require_root to false
      actionWithOverride = Action(
        id: 'test-action-with-override',
        type: 'copy',
        properties: {'require_root': false},
        parent: resourceWithRoot.properties, // Pass parent properties
      );

      // Create an action without override
      actionWithoutOverride = Action(
        id: 'test-action-without-override',
        type: 'copy',
        properties: {},
        parent: resourceWithRoot.properties, // Pass parent properties
      );
    });

    test('Resource with require_root=true should inherit to actions', () {
      final module = TestResourceModule(resourceWithRoot, actionWithoutOverride);
      
      expect(module.shouldUsePrivilegeEscalation(), isTrue,
          reason: 'Action should inherit require_root=true from resource');
    });

    test('Resource with require_root=false should inherit to actions', () {
      final actionWithoutRoot = Action(
        id: 'test-action-without-root',
        type: 'copy',
        properties: {},
        parent: resourceWithoutRoot.properties, // Pass parent properties
      );
      
      final module = TestResourceModule(resourceWithoutRoot, actionWithoutRoot);
      
      expect(module.shouldUsePrivilegeEscalation(), isFalse,
          reason: 'Action should inherit require_root=false from resource');
    });

    test('Action should override resource require_root=true to false', () {
      final module = TestResourceModule(resourceWithRoot, actionWithOverride);
      
      expect(module.shouldUsePrivilegeEscalation(), isFalse,
          reason: 'Action should override resource require_root=true to false');
    });

    test('Action should override resource require_root=false to true', () {
      final actionWithTrueOverride = Action(
        id: 'test-action-with-true-override',
        type: 'copy',
        properties: {'require_root': true},
        parent: resourceWithoutRoot.properties,
      );
      
      final module = TestResourceModule(resourceWithoutRoot, actionWithTrueOverride);
      
      expect(module.shouldUsePrivilegeEscalation(), isTrue,
          reason: 'Action should override resource require_root=false to true');
    });

    test('Resource with explicit require_root=false should work', () {
      final resourceWithExplicitFalse = ResourceModel(
        id: 'test-resource-explicit-false',
        source: '/tmp/source.txt',
        destination: '/tmp/test.txt',
        actions: [],
        properties: {'require_root': false},
      );
      
      final actionWithoutOverride = Action(
        id: 'test-action-without-override',
        type: 'copy',
        properties: {},
        parent: resourceWithExplicitFalse.properties,
      );
      
      final module = TestResourceModule(resourceWithExplicitFalse, actionWithoutOverride);
      
      expect(module.shouldUsePrivilegeEscalation(), isFalse,
          reason: 'Action should inherit explicit require_root=false from resource');
    });

    test('Action with explicit require_root=true should override resource false', () {
      final actionWithTrueOverride = Action(
        id: 'test-action-with-true-override',
        type: 'copy',
        properties: {'require_root': true},
        parent: resourceWithoutRoot.properties,
      );
      
      final resourceWithExplicitFalse = ResourceModel(
        id: 'test-resource-explicit-false',
        source: '/tmp/source.txt',
        destination: '/tmp/test.txt',
        actions: [],
        properties: {'require_root': false},
      );
      
      final module = TestResourceModule(resourceWithExplicitFalse, actionWithTrueOverride);
      
      expect(module.shouldUsePrivilegeEscalation(), isTrue,
          reason: 'Action should override resource require_root=false to true');
    });

    test('Multiple actions with same resource should inherit correctly', () {
      final action1 = TestResourceModule(resourceWithRoot, actionWithoutOverride);
      final action2 = TestResourceModule(resourceWithRoot, actionWithOverride);
      
      expect(action1.shouldUsePrivilegeEscalation(), isTrue,
          reason: 'First action should inherit require_root=true from resource');
      expect(action2.shouldUsePrivilegeEscalation(), isFalse,
          reason: 'Second action should override to require_root=false');
    });

    test('Resource properties should be accessible', () {
      expect(resourceWithRoot.properties['require_root'], isTrue);
      expect(resourceWithoutRoot.properties['require_root'], isNull);
      
      // Test that properties are properly stored
      final customResource = ResourceModel(
        id: 'custom-resource',
        source: '/tmp/source.txt',
        destination: '/tmp/test.txt',
        actions: [],
        properties: {
          'require_root': true,
          'custom_prop': 'custom_value',
          'another_prop': 42,
        },
      );
      
      expect(customResource.properties['require_root'], isTrue);
      expect(customResource.properties['custom_prop'], equals('custom_value'));
      expect(customResource.properties['another_prop'], equals(42));
    });

    test('Action properties should be accessible', () {
      expect(actionWithOverride.properties['require_root'], isFalse);
      expect(actionWithoutOverride.properties['require_root'], isNull);
      
      // Test that action properties are properly stored
      final customAction = Action(
        id: 'custom-action',
        type: 'copy',
        properties: {
          'require_root': true,
          'custom_prop': 'action_value',
          'another_prop': 123,
        },
        parent: resourceWithRoot.properties,
      );
      
      expect(customAction.properties['require_root'], isTrue);
      expect(customAction.properties['custom_prop'], equals('action_value'));
      expect(customAction.properties['another_prop'], equals(123));
    });

    test('Edge cases with null and undefined values', () {
      // Test with null values
      final resourceWithNull = ResourceModel(
        id: 'test-resource-null',
        source: '/tmp/source.txt',
        destination: '/tmp/test.txt',
        actions: [],
        properties: {'require_root': null},
      );
      
      final actionWithoutOverride = Action(
        id: 'test-action-without-override',
        type: 'copy',
        properties: {},
        parent: resourceWithNull.properties,
      );
      
      final moduleWithNull = TestResourceModule(resourceWithNull, actionWithoutOverride);
      expect(moduleWithNull.shouldUsePrivilegeEscalation(), isFalse,
          reason: 'Null require_root should default to false');
      
      // Test with undefined property
      final resourceWithUndefined = ResourceModel(
        id: 'test-resource-undefined',
        source: '/tmp/source.txt',
        destination: '/tmp/test.txt',
        actions: [],
        properties: {'other_prop': 'value'},
      );
      
      final actionWithoutOverride2 = Action(
        id: 'test-action-without-override-2',
        type: 'copy',
        properties: {},
        parent: resourceWithUndefined.properties,
      );
      
      final moduleWithUndefined = TestResourceModule(resourceWithUndefined, actionWithoutOverride2);
      expect(moduleWithUndefined.shouldUsePrivilegeEscalation(), isFalse,
          reason: 'Undefined require_root should default to false');
    });
  });
}

/// Test implementation of ResourceModule for testing privilege inheritance
class TestResourceModule extends ResourceModule {
  TestResourceModule(ResourceModel file, Action action) 
      : super(file, action, allowedActions: const ['copy']);
  
  @override
  Future<void> execute() async {
    // Test implementation - not used in these tests
  }
}
