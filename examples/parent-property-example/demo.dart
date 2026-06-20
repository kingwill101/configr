import 'dart:io';
import 'package:configr/models/action.dart';
import 'package:configr/models/file_model.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/privellage_escallation.dart';

void main() async {
  print('🔧 Parent Property Example Demo\n');
  
  // Example 1: Basic inheritance
  print('📋 Example 1: Basic Inheritance');
  await demonstrateBasicInheritance();
  
  print('\n' + '='*60 + '\n');
  
  // Example 2: Override behavior
  print('📋 Example 2: Override Behavior');
  await demonstrateOverrideBehavior();
  
  print('\n' + '='*60 + '\n');
  
  // Example 3: Complex inheritance chain
  print('📋 Example 3: Complex Inheritance Chain');
  await demonstrateComplexInheritance();
  
  print('\n' + '='*60 + '\n');
  
  // Example 4: Privilege lock demonstration
  print('📋 Example 4: Privilege Lock with Parent Properties');
  await demonstratePrivilegeLock();
  
  print('\n✅ Demo completed successfully!');
}

/// Example 1: Basic inheritance from parent resource
Future<void> demonstrateBasicInheritance() async {
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
    parent: resource.properties, // Inherits all parent properties
  );

  final permissionsAction = Action(
    id: 'permissions-action',
    type: 'permissions',
    properties: {'mode': '644'},
    parent: resource.properties, // Inherits all parent properties
  );

  // Create modules and test inheritance
  final copyModule = DemoResourceModule(resource, copyAction);
  final permissionsModule = DemoResourceModule(resource, permissionsAction);

  print('Resource properties: ${resource.properties}');
  print('Copy action parent: ${copyAction.parent}');
  print('Permissions action parent: ${permissionsAction.parent}');
  
  print('Copy action requires privileges: ${copyModule.shouldUsePrivilegeEscalation()}');
  print('Permissions action requires privileges: ${permissionsModule.shouldUsePrivilegeEscalation()}');
  
  // Demonstrate accessing parent properties
  print('Copy action can access parent environment: ${copyAction.parent?['environment']}');
  print('Permissions action can access parent source: ${permissionsAction.parent?['source']}');
}

/// Example 2: Override behavior
Future<void> demonstrateOverrideBehavior() async {
  final resource = ResourceModel(
    id: 'mixed-resource',
    source: 'user_config.yml',
    destination: '/etc/myapp/user_config.yml',
    actions: [],
    properties: {
      'require_root': true, // Default: all actions privileged
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

  final copyModule = DemoResourceModule(resource, copyAction);
  final permissionsModule = DemoResourceModule(resource, permissionsAction);

  print('Resource require_root: ${resource.properties['require_root']}');
  print('Copy action (inherits): ${copyModule.shouldUsePrivilegeEscalation()}');
  print('Permissions action (overrides): ${permissionsModule.shouldUsePrivilegeEscalation()}');
  
  // Show that both actions still have access to other parent properties
  print('Copy action parent source: ${copyAction.parent?['source']}');
  print('Permissions action parent source: ${permissionsAction.parent?['source']}');
}

/// Example 3: Complex inheritance chain
Future<void> demonstrateComplexInheritance() async {
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
      parent: resource.properties, // Inherits everything
    ),
    Action(
      id: 'permissions',
      type: 'permissions',
      properties: {'mode': '644'},
      parent: resource.properties, // Inherits everything
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

  print('Resource properties: ${resource.properties}');
  print('\nAction inheritance analysis:');
  
  for (final action in actions) {
    final module = DemoResourceModule(resource, action);
    final requiresPrivileges = module.shouldUsePrivilegeEscalation();
    
    print('${action.id}:');
    print('  - Requires privileges: $requiresPrivileges');
    print('  - Parent environment: ${action.parent?['environment']}');
    print('  - Parent service_type: ${action.parent?['service_type']}');
    print('  - Parent custom_prop: ${action.parent?['custom_prop']}');
    print('');
  }
}

/// Example 4: Privilege lock demonstration
Future<void> demonstratePrivilegeLock() async {
  print('Demonstrating privilege lock with parent properties...');
  
  // Reset privilege lock for clean demo
  PrivilegeLock.reset();
  final lock = PrivilegeLock.instance;
  
  print('Initial privilege lock state: ${lock.isActive}');
  
  // Simulate a resource that requires privileges
  final privilegedResource = ResourceModel(
    id: 'privileged-resource',
    source: 'secure_config.yml',
    destination: '/etc/secure/config.yml',
    actions: [],
    properties: {
      'require_root': true,
      'source': 'secure_config.yml',
      'destination': '/etc/secure/config.yml',
      'security_level': 'high',
    },
  );

  // Create actions that will use the privilege lock
  final actions = [
    Action(
      id: 'copy-secure',
      type: 'copy',
      properties: {},
      parent: privilegedResource.properties,
    ),
    Action(
      id: 'set-permissions',
      type: 'permissions',
      properties: {'mode': '600'},
      parent: privilegedResource.properties,
    ),
    Action(
      id: 'validate-secure',
      type: 'validate',
      properties: {'require_root': false}, // Override: no privileges needed
      parent: privilegedResource.properties,
    ),
  ];

  // Simulate privilege escalation workflow
  print('\nSimulating privilege escalation workflow:');
  
  for (final action in actions) {
    final module = DemoResourceModule(privilegedResource, action);
    final needsPrivileges = module.shouldUsePrivilegeEscalation();
    
    print('Processing ${action.id}:');
    print('  - Needs privileges: $needsPrivileges');
    print('  - Parent security_level: ${action.parent?['security_level']}');
    
    if (needsPrivileges) {
      if (!lock.isActive) {
        print('  - Acquiring privilege lock...');
        lock.acquire();
        print('  - Privilege lock acquired: ${lock.isActive}');
      } else {
        print('  - Using existing privilege lock');
        lock.acquire(); // Updates last used time
      }
    } else {
      print('  - No privileges needed, skipping lock');
    }
    
    print('  - Current lock state: ${lock.isActive}');
    print('  - Time until timeout: ${lock.timeUntilTimeout?.inMinutes} minutes');
    print('');
  }
  
  // Release the lock
  print('Releasing privilege lock...');
  lock.release();
  print('Final privilege lock state: ${lock.isActive}');
}

/// Demo implementation of ResourceModule for examples
class DemoResourceModule extends ResourceModule {
  DemoResourceModule(ResourceModel file, Action action) 
      : super(file, action, allowedActions: const [
          'copy', 'permissions', 'backup', 'validate', 
          'systemd_reload', 'cleanup'
        ]);
  
  @override
  Future<void> execute() async {
    // Demo implementation - just print what would happen
    final needsPrivileges = shouldUsePrivilegeEscalation();
    final parentSource = action.parent?['source'];
    final parentDestination = action.parent?['destination'];
    
    print('    Executing ${action.type} action:');
    print('      - Source: $parentSource');
    print('      - Destination: $parentDestination');
    print('      - Requires privileges: $needsPrivileges');
    
    if (needsPrivileges) {
      print('      - Would run with elevated privileges');
    } else {
      print('      - Would run with normal privileges');
    }
  }
}
