# Parent Property Example

This example demonstrates how the parent property feature works in Configr, allowing actions to inherit properties from their parent resources and override them when needed.

## Overview

The parent property feature provides a clean way for actions to access their parent resource's properties without having to pass the resource object around. This enables:

- **Property Inheritance**: Actions automatically inherit properties from their parent resource
- **Selective Override**: Actions can override specific parent properties while keeping others
- **Clean Architecture**: No need to pass resource objects to actions
- **Better Encapsulation**: Each action carries its own context

## Files

- `config` - Example configuration file showing different inheritance scenarios
- `demo.dart` - Interactive demonstration script
- `README.md` - This documentation

## Configuration Examples

### Example 1: Basic Inheritance
```hcl
resource {
  type "file"
  source "app_config.yml"
  destination "/etc/myapp/config.yml"
  require_root = true  # All child actions inherit this

  actions {
    copy {}  # Inherits require_root = true
    permissions {
      mode "644"  # Inherits require_root = true
    }
  }
}
```

### Example 2: Override Behavior
```hcl
resource {
  type "file"
  source "user_config.yml"
  destination "/etc/myapp/user_config.yml"
  require_root = true  # Default for all actions

  actions {
    copy {}  # Inherits require_root = true
    permissions {
      mode "644"
      require_root = false  # Override: no privileges needed
    }
  }
}
```

### Example 3: Complex Inheritance
```hcl
resource {
  type "file"
  source "service_config.yml"
  destination "/etc/systemd/system/myapp.service"
  require_root = true
  custom_prop = "service_config"
  environment = "production"

  actions {
    copy {}  # Inherits all parent properties
    permissions {
      mode "644"  # Inherits all parent properties
    }
    validate {
      require_root = false  # Override privilege requirement
      # Still inherits custom_prop and environment
    }
  }
}
```

## Running the Demo

```bash
# Run the interactive demonstration
dart examples/parent-property-example/demo.dart
```

The demo will show:

1. **Basic Inheritance** - How actions inherit properties from their parent resource
2. **Override Behavior** - How actions can override specific parent properties
3. **Complex Inheritance** - Multiple actions with different inheritance patterns
4. **Privilege Lock Integration** - How parent properties work with the privilege escalation system

## Key Concepts

### Parent Property Access
Actions can access their parent's properties through the `parent` field:

```dart
final action = Action(
  type: 'copy',
  properties: {},
  parent: {
    'require_root': true,
    'source': '/tmp/source.txt',
    'destination': '/etc/test.txt',
  },
);

// Access parent properties
final requiresRoot = action.parent?['require_root'] as bool? ?? false;
final source = action.parent?['source'] as String?;
```

### Inheritance Chain
The inheritance follows this pattern:
1. **Resource Level**: Properties defined at the resource level
2. **Action Level**: Properties defined at the action level (can override resource properties)
3. **Final Result**: Action properties take precedence over resource properties

### Privilege Escalation Integration
The `shouldUsePrivilegeEscalation()` method uses the parent property to determine privilege requirements:

```dart
bool shouldUsePrivilegeEscalation() {
  // Check if action has explicit require_root override
  final actionRequireRoot = action.properties['require_root'] as bool?;
  if (actionRequireRoot != null) {
    return actionRequireRoot;
  }
  
  // Fall back to resource-level require_root setting from parent properties
  return action.parent?['require_root'] as bool? ?? false;
}
```

## Benefits

1. **Cleaner Code**: No need to pass resource objects around
2. **Better Encapsulation**: Each action carries its own context
3. **Flexible Inheritance**: Actions can inherit some properties and override others
4. **Maintainable**: Clear inheritance chain from resource to action
5. **Extensible**: Easy to add more parent properties in the future

## Use Cases

- **Privilege Management**: Actions inherit privilege requirements from resources
- **Configuration Sharing**: Actions share configuration values from their parent resource
- **Environment Context**: Actions inherit environment-specific settings
- **Security Context**: Actions inherit security-related properties
- **Custom Properties**: Actions can access any custom properties defined at the resource level
