import 'package:test/test.dart';
import 'package:configr/models/action.dart';
import 'package:configr/models/file_model.dart';
import 'package:configr/modules/resource/resource_module.dart';

void main() {
  group('Parent Property Example Tests', () {
    test('Basic inheritance example', () {
      // Create a resource with require_root = true
      final resource = ResourceModel(
        id: 'app-config',
        source: 'app_config.yml',
        destination: '/etc/myapp/config.yml',
        actions: [],
        properties: {
          'require_root': true,
          'source': 'app_config.yml',
          'destination': '/etc/myapp/config.yml',
          'environment': 'production',
        },
      );

      // Create actions that inherit from the parent
      final copyAction = Action(
        id: 'copy-action',
        type: 'copy',
        properties: {},
        parent: resource.properties,
      );

      final permissionsAction = Action(
        id: 'permissions-action',
        type: 'permissions',
        properties: {'mode': '644'},
        parent: resource.properties,
      );

      // Test inheritance
      final copyModule = TestResourceModule(resource, copyAction);
      final permissionsModule = TestResourceModule(resource, permissionsAction);

      expect(copyModule.shouldUsePrivilegeEscalation(), isTrue);
      expect(permissionsModule.shouldUsePrivilegeEscalation(), isTrue);
      
      // Test parent property access
      expect(copyAction.parent?['environment'], equals('production'));
      expect(permissionsAction.parent?['source'], equals('app_config.yml'));
    });

    test('Override behavior example', () {
      final resource = ResourceModel(
        id: 'mixed-resource',
        source: 'user_config.yml',
        destination: '/etc/myapp/user_config.yml',
        actions: [],
        properties: {
          'require_root': true,
          'source': 'user_config.yml',
          'destination': '/etc/myapp/user_config.yml',
        },
      );

      // Action that inherits from parent
      final copyAction = Action(
        id: 'copy-inherit',
        type: 'copy',
        properties: {},
        parent: resource.properties,
      );

      // Action that overrides parent setting
      final permissionsAction = Action(
        id: 'permissions-override',
        type: 'permissions',
        properties: {
          'mode': '644',
          'require_root': false, // Override parent's require_root = true
        },
        parent: resource.properties,
      );

      final copyModule = TestResourceModule(resource, copyAction);
      final permissionsModule = TestResourceModule(resource, permissionsAction);

      expect(copyModule.shouldUsePrivilegeEscalation(), isTrue);
      expect(permissionsModule.shouldUsePrivilegeEscalation(), isFalse);
      
      // Both actions should still have access to other parent properties
      expect(copyAction.parent?['source'], equals('user_config.yml'));
      expect(permissionsAction.parent?['source'], equals('user_config.yml'));
    });

    test('Complex inheritance chain example', () {
      final resource = ResourceModel(
        id: 'service-config',
        source: 'service_config.yml',
        destination: '/etc/systemd/system/myapp.service',
        actions: [],
        properties: {
          'require_root': true,
          'source': 'service_config.yml',
          'destination': '/etc/systemd/system/myapp.service',
          'custom_prop': 'service_config',
          'environment': 'production',
          'service_type': 'systemd',
        },
      );

      // Create multiple actions with different behaviors
      final actions = [
        Action(
          id: 'copy',
          type: 'copy',
          properties: {},
          parent: resource.properties,
        ),
        Action(
          id: 'permissions',
          type: 'permissions',
          properties: {'mode': '644'},
          parent: resource.properties,
        ),
        Action(
          id: 'systemd-reload',
          type: 'systemd_reload',
          properties: {'require_root': true}, // Explicit override (same as parent)
          parent: resource.properties,
        ),
        Action(
          id: 'validate',
          type: 'validate',
          properties: {'require_root': false}, // Override: no privileges needed
          parent: resource.properties,
        ),
      ];

      final modules = actions.map((action) => TestResourceModule(resource, action)).toList();

      // Test privilege inheritance
      expect(modules[0].shouldUsePrivilegeEscalation(), isTrue); // copy
      expect(modules[1].shouldUsePrivilegeEscalation(), isTrue); // permissions
      expect(modules[2].shouldUsePrivilegeEscalation(), isTrue); // systemd-reload
      expect(modules[3].shouldUsePrivilegeEscalation(), isFalse); // validate

      // Test that all actions have access to parent properties
      for (final action in actions) {
        expect(action.parent?['environment'], equals('production'));
        expect(action.parent?['service_type'], equals('systemd'));
        expect(action.parent?['custom_prop'], equals('service_config'));
      }
    });

    test('JSON serialization example', () {
      final resource = ResourceModel(
        id: 'test-resource',
        source: 'test.yml',
        destination: '/tmp/test.yml',
        actions: [],
        properties: {
          'require_root': true,
          'source': 'test.yml',
          'destination': '/tmp/test.yml',
          'custom_prop': 'test_value',
        },
      );

      final action = Action(
        id: 'test-action',
        type: 'copy',
        properties: {'mode': '644'},
        parent: resource.properties,
      );

      // Test JSON serialization
      final json = action.toJson();
      expect(json['parent'], isNotNull);
      expect(json['parent']['require_root'], isTrue);
      expect(json['parent']['source'], equals('test.yml'));
      expect(json['parent']['custom_prop'], equals('test_value'));

      // Test JSON deserialization
      final restoredAction = Action.fromJson(json);
      expect(restoredAction.parent, isNotNull);
      expect(restoredAction.parent!['require_root'], isTrue);
      expect(restoredAction.parent!['source'], equals('test.yml'));
      expect(restoredAction.parent!['custom_prop'], equals('test_value'));
    });
  });
}

/// Test implementation of ResourceModule for examples
class TestResourceModule extends ResourceModule {
  TestResourceModule(ResourceModel file, Action action) 
      : super(file, action, allowedActions: const [
          'copy', 'permissions', 'backup', 'validate', 
          'systemd_reload', 'cleanup'
        ]);
  
  @override
  Future<void> execute() async {
    // Test implementation - not used in these tests
  }
}
