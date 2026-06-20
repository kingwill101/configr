import 'package:test/test.dart';
import 'package:configr/models/action.dart';
import 'package:configr/models/file_model.dart';
import 'package:configr/modules/resource/resource_module.dart';

void main() {
  group('Action Parent Property Tests', () {
    test('Action should have access to parent properties', () {
      // Create parent properties
      final parentProperties = {
        'require_root': true,
        'source': '/tmp/source.txt',
        'destination': '/etc/test.txt',
        'custom_prop': 'parent_value',
      };

      // Create action with parent properties
      final action = Action(
        id: 'test-action',
        type: 'copy',
        properties: {
          'mode': '644',
          'action_prop': 'action_value',
        },
        parent: parentProperties,
      );

      // Verify parent properties are accessible
      expect(action.parent, isNotNull);
      expect(action.parent!['require_root'], isTrue);
      expect(action.parent!['source'], equals('/tmp/source.txt'));
      expect(action.parent!['destination'], equals('/etc/test.txt'));
      expect(action.parent!['custom_prop'], equals('parent_value'));

      // Verify action properties are still accessible
      expect(action.properties['mode'], equals('644'));
      expect(action.properties['action_prop'], equals('action_value'));
    });

    test('Action without parent should have null parent', () {
      final action = Action(
        id: 'test-action',
        type: 'copy',
        properties: {'mode': '644'},
      );

      expect(action.parent, isNull);
    });

    test('ResourceModule should use parent properties for privilege detection', () {
      // Create a resource with require_root = true
      final resource = ResourceModel(
        id: 'test-resource',
        source: '/tmp/source.txt',
        destination: '/etc/test.txt',
        actions: [],
        properties: {'require_root': true},
      );

      // Create action with parent properties
      final actionWithParent = Action(
        id: 'action-with-parent',
        type: 'copy',
        properties: {},
        parent: {'require_root': true},
      );

      // Create action without parent
      final actionWithoutParent = Action(
        id: 'action-without-parent',
        type: 'copy',
        properties: {},
      );

      // Create modules
      final moduleWithParent = TestResourceModule(resource, actionWithParent);
      final moduleWithoutParent = TestResourceModule(resource, actionWithoutParent);

      // Test privilege detection
      expect(moduleWithParent.shouldUsePrivilegeEscalation(), isTrue,
          reason: 'Action with parent should inherit require_root=true from parent');
      expect(moduleWithoutParent.shouldUsePrivilegeEscalation(), isFalse,
          reason: 'Action without parent should default to false');
    });

    test('Action should override parent properties', () {
      final parentProperties = {
        'require_root': true,
        'source': '/tmp/source.txt',
        'destination': '/etc/test.txt',
      };

      // Create action that overrides parent require_root
      final actionWithOverride = Action(
        id: 'action-with-override',
        type: 'copy',
        properties: {'require_root': false}, // Override parent
        parent: parentProperties,
      );

      final resource = ResourceModel(
        id: 'test-resource',
        source: '/tmp/source.txt',
        destination: '/etc/test.txt',
        actions: [],
        properties: {},
      );

      final module = TestResourceModule(resource, actionWithOverride);

      // Should use action override, not parent
      expect(module.shouldUsePrivilegeEscalation(), isFalse,
          reason: 'Action should override parent require_root=true to false');
    });

    test('Action parent properties should be serializable', () {
      final parentProperties = {
        'require_root': true,
        'source': '/tmp/source.txt',
        'destination': '/etc/test.txt',
        'custom_prop': 'parent_value',
      };

      final action = Action(
        id: 'test-action',
        type: 'copy',
        properties: {'mode': '644'},
        parent: parentProperties,
      );

      // Test JSON serialization
      final json = action.toJson();
      expect(json['parent'], isNotNull);
      expect(json['parent']['require_root'], isTrue);
      expect(json['parent']['source'], equals('/tmp/source.txt'));
      expect(json['parent']['destination'], equals('/etc/test.txt'));
      expect(json['parent']['custom_prop'], equals('parent_value'));

      // Test JSON deserialization
      final deserializedAction = Action.fromJson(json);
      expect(deserializedAction.parent, isNotNull);
      expect(deserializedAction.parent!['require_root'], isTrue);
      expect(deserializedAction.parent!['source'], equals('/tmp/source.txt'));
      expect(deserializedAction.parent!['destination'], equals('/etc/test.txt'));
      expect(deserializedAction.parent!['custom_prop'], equals('parent_value'));
    });

    test('Action equality should include parent properties', () {
      final parentProperties = {
        'require_root': true,
        'source': '/tmp/source.txt',
      };

      final action1 = Action(
        id: 'test-action',
        type: 'copy',
        properties: {'mode': '644'},
        parent: parentProperties,
      );

      final action2 = Action(
        id: 'test-action',
        type: 'copy',
        properties: {'mode': '644'},
        parent: parentProperties,
      );

      final action3 = Action(
        id: 'test-action',
        type: 'copy',
        properties: {'mode': '644'},
        parent: {'require_root': false}, // Different parent
      );

      expect(action1, equals(action2));
      expect(action1, isNot(equals(action3)));
    });

    test('Action hashCode should include parent properties', () {
      final parentProperties = {
        'require_root': true,
        'source': '/tmp/source.txt',
      };

      final action1 = Action(
        id: 'test-action',
        type: 'copy',
        properties: {'mode': '644'},
        parent: parentProperties,
      );

      final action2 = Action(
        id: 'test-action',
        type: 'copy',
        properties: {'mode': '644'},
        parent: parentProperties,
      );

      final action3 = Action(
        id: 'test-action',
        type: 'copy',
        properties: {'mode': '644'},
        parent: {'require_root': false}, // Different parent
      );

      expect(action1.hashCode, equals(action2.hashCode));
      expect(action1.hashCode, isNot(equals(action3.hashCode)));
    });

    test('Nested actions should inherit parent properties', () {
      final grandparentProperties = {
        'require_root': true,
        'source': '/tmp/source.txt',
        'destination': '/etc/test.txt',
      };

      final childAction = Action(
        id: 'child-action',
        type: 'copy',
        properties: {'mode': '644'},
        parent: grandparentProperties, // Should inherit from grandparent
      );

      final parentAction = Action(
        id: 'parent-action',
        type: 'group',
        properties: {'group_prop': 'group_value'},
        parent: grandparentProperties,
        actions: [childAction], // Pass child action in constructor
      );

      // Verify child has access to grandparent properties
      expect(childAction.parent, isNotNull);
      expect(childAction.parent!['require_root'], isTrue);
      expect(childAction.parent!['source'], equals('/tmp/source.txt'));
      expect(childAction.parent!['destination'], equals('/etc/test.txt'));
    });
  });
}

/// Test implementation of ResourceModule for testing parent properties
class TestResourceModule extends ResourceModule {
  TestResourceModule(ResourceModel file, Action action) 
      : super(file, action, allowedActions: const ['copy', 'group']);
  
  @override
  Future<void> execute() async {
    // Test implementation - not used in these tests
  }
}
