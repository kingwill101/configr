# Migration Guide: Old CLI to New CommandRunner

## Overview

This guide helps you migrate from the old manual argument parsing system to the new CommandRunner-based architecture. The migration provides better error handling, automatic help generation, and improved maintainability.

## Key Changes

### 1. Command Structure

#### Before (Old System)
```dart
// lib/commands/old_command.dart
class OldCommand extends Command {
  final ConfigManager configManager;
  
  OldCommand(this.configManager);
  
  @override
  Future<void> execute() async {
    // Manual argument parsing
    final args = ArgResults.from(['--force', '--config', 'myconfig']);
    
    // Command logic
    if (args['force'] == true) {
      // Handle force flag
    }
  }
}
```

#### After (New System)
```dart
// lib/commands/new_command.dart
class NewCommand extends BaseCommand {
  NewCommand() {
    // Define options in constructor
    argParser.addFlag('force', abbr: 'f', help: 'Force operation');
    argParser.addOption('config', abbr: 'c', help: 'Config file path');
  }
  
  @override
  String get name => 'new-command';
  
  @override
  String get description => 'Description of the command';
  
  @override
  void executeCommand() {
    // Access parsed arguments
    final force = argResults?['force'] as bool? ?? false;
    final configPath = argResults?['config'] as String?;
    
    // Command logic
    if (force) {
      // Handle force flag
    }
  }
}
```

### 2. Main Entry Point

#### Before (Manual Parsing)
```dart
// bin/main.dart
void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addCommand('init')
    ..addCommand('apply', ArgParser()..addFlag('force'))
    ..addOption('config', abbr: 'c');
    
  final argResults = parser.parse(arguments);
  
  final configManager = ConfigManager(/* ... */);
  
  switch (argResults.command?.name) {
    case 'init':
      final command = InitCommand(configManager);
      await command.execute();
      break;
    case 'apply':
      final force = argResults.command!['force'] as bool;
      final command = ApplyCommand(configManager, force: force);
      await command.execute();
      break;
    // ... more cases
  }
}
```

#### After (CommandRunner)
```dart
// bin/main.dart
class ConfigrCommandRunner extends CommandRunner<void> {
  ConfigrCommandRunner() : super('configr', 'A configuration management tool') {
    argParser.addOption('config', abbr: 'c', help: 'Path to config file');
    
    addCommand(InitCommand());
    addCommand(ApplyCommand());
    // ... more commands
  }
  
  @override
  Future<void> run(Iterable<String> args) async {
    initLogging();
    
    final configPath = argResults?['config'] as String? ?? 'config';
    final configManager = ConfigManager(/* ... */);
    
    // Set configManager for all commands
    for (final command in commands.values) {
      if (command is BaseCommand) {
        command.configManager = configManager;
      }
    }
    
    await super.run(args);
  }
}

void main(List<String> arguments) async {
  final runner = ConfigrCommandRunner();
  await runner.run(arguments);
}
```

## Step-by-Step Migration

### Step 1: Update Command Class

1. **Change base class**: `extends Command` → `extends BaseCommand`
2. **Remove constructor parameter**: Remove `ConfigManager` parameter
3. **Add name and description getters**
4. **Move argument parsing to constructor**
5. **Rename execute method**: `execute()` → `executeCommand()`

### Step 2: Define Command Options

Move all argument parsing from manual `ArgParser` usage to the constructor:

```dart
// Before
final parser = ArgParser()..addFlag('force')..addOption('output');

// After
class MyCommand extends BaseCommand {
  MyCommand() {
    argParser.addFlag('force', abbr: 'f', help: 'Force operation');
    argParser.addOption('output', abbr: 'o', help: 'Output file');
  }
}
```

### Step 3: Update Argument Access

```dart
// Before
final force = argResults['force'] as bool;
final output = argResults['output'] as String;

// After
final force = argResults?['force'] as bool? ?? false;
final output = argResults?['output'] as String?;
```

### Step 4: Access Configuration Manager

```dart
// Before
class OldCommand extends Command {
  final ConfigManager configManager;
  OldCommand(this.configManager);
}

// After
class NewCommand extends BaseCommand {
  @override
  void executeCommand() {
    // Access via getter
    final config = configManager;
  }
}
```

### Step 5: Register Command

Add your command to the `ConfigrCommandRunner`:

```dart
class ConfigrCommandRunner extends CommandRunner<void> {
  ConfigrCommandRunner() : super('configr', 'A configuration management tool') {
    // ... existing commands ...
    addCommand(MyCommand()); // Add your migrated command
  }
}
```

## Common Migration Patterns

### Flag Options
```dart
// Before
parser.addFlag('force', abbr: 'f', defaultsTo: false);

// After
argParser.addFlag('force', abbr: 'f', help: 'Force operation', defaultsTo: false);
```

### String Options
```dart
// Before
parser.addOption('config', abbr: 'c');

// After
argParser.addOption('config', abbr: 'c', help: 'Configuration file path');
```

### Multi-Options
```dart
// Before
parser.addMultiOption('files');

// After
argParser.addMultiOption('files', help: 'Files to process');
```

### Positional Arguments
```dart
// Before
parser.addPositional('target');

// After
argParser.addMultiOption('files', help: 'Target files'); // Use rest property
```

## Error Handling Changes

### Before
```dart
try {
  final argResults = parser.parse(arguments);
  // Handle arguments
} catch (e) {
  print('Error: $e');
  printUsage(parser);
  exit(1);
}
```

### After
```dart
@override
void executeCommand() {
  try {
    // Command logic
  } catch (e) {
    logger.severe('Command failed: $e');
    print('Error: $e');
    print('Use --help for usage information');
    exit(1);
  }
}
```

## Testing Changes

### Before
```dart
void main() {
  test('command works', () {
    final command = OldCommand(mockConfigManager);
    command.execute();
    // Assertions
  });
}
```

### After
```dart
void main() {
  test('command works', () {
    final command = NewCommand();
    command.configManager = mockConfigManager;
    command.executeCommand();
    // Assertions
  });
}
```

## Benefits of Migration

### 1. Automatic Help Generation
- Commands automatically get `--help` functionality
- Consistent help formatting across all commands
- Built-in usage examples and descriptions

### 2. Better Error Handling
- Automatic argument validation
- Clear error messages for invalid arguments
- Consistent error reporting

### 3. Reduced Boilerplate
- No manual argument parsing setup
- No manual command routing
- Automatic command registration

### 4. Improved Maintainability
- Consistent command structure
- Easier to add new commands
- Better separation of concerns

## Backward Compatibility

The new CLI system maintains backward compatibility:

- **Command Names**: All existing command names work the same
- **Arguments**: All existing arguments and options are preserved
- **Behavior**: Commands behave identically to the old system
- **Scripts**: Existing scripts continue to work without changes

## Troubleshooting

### Common Issues

1. **Missing configManager**: Ensure you set `command.configManager` before calling `run()`
2. **Argument parsing errors**: Check that all options are defined in the constructor
3. **Help not working**: Ensure you've registered the command with `addCommand()`

### Migration Checklist

- [ ] Command extends `BaseCommand`
- [ ] Constructor defines all options with `argParser`
- [ ] `name` and `description` getters implemented
- [ ] `executeCommand()` method implemented
- [ ] Command registered in `ConfigrCommandRunner`
- [ ] Tests updated to use new structure
- [ ] Documentation updated

## Getting Help

If you encounter issues during migration:

1. Check existing migrated commands for examples
2. Review the CommandRunner documentation
3. Run `dart bin/main.dart --help` to see the new help system
4. Test your migrated command with various arguments
