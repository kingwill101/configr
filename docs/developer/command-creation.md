# Command Development Guide

## Overview

This guide explains how to create new commands for Configr using the modern CommandRunner-based architecture. All commands extend the `BaseCommand` class and integrate seamlessly with the CLI system.

## Creating a New Command

### 1. Basic Command Structure

```dart
import 'package:configr/commands/base_command.dart';

class MyCommand extends BaseCommand {
  MyCommand() {
    // Add command-specific options and arguments
    argParser.addFlag('verbose', abbr: 'v', help: 'Enable verbose output');
    argParser.addOption('output', abbr: 'o', help: 'Output file path');
  }

  @override
  String get name => 'my-command';

  @override
  String get description => 'Description of what this command does';

  @override
  void executeCommand() {
    // Access command options
    final verbose = argResults?['verbose'] as bool? ?? false;
    final outputPath = argResults?['output'] as String?;
    
    // Access configuration manager
    final config = configManager;
    
    // Implement command logic
    print('Executing my command...');
    if (verbose) {
      print('Verbose mode enabled');
    }
    if (outputPath != null) {
      print('Output path: $outputPath');
    }
  }
}
```

### 2. Registering the Command

Add your command to the main CLI runner:

```dart
// In bin/main.dart
class ConfigrCommandRunner extends CommandRunner<void> {
  ConfigrCommandRunner() : super('configr', 'A configuration management tool') {
    // ... existing commands ...
    addCommand(MyCommand()); // Add your new command
  }
}
```

### 3. Command Options and Arguments

#### Flags (Boolean Options)
```dart
argParser.addFlag(
  'force',
  abbr: 'f',
  help: 'Force operation without confirmation',
  defaultsTo: false,
);
```

#### Options (String Values)
```dart
argParser.addOption(
  'config',
  abbr: 'c',
  help: 'Path to configuration file',
  defaultsTo: 'config',
);
```

#### Multi-Options (Multiple Values)
```dart
argParser.addMultiOption(
  'files',
  help: 'Files to process',
);
```

#### Positional Arguments
```dart
argParser.addMultiOption(
  'files',
  help: 'Files to process',
);
```

### 4. Accessing Command Results

```dart
@override
void executeCommand() {
  // Access parsed arguments
  final args = argResults;
  
  // Get flag values
  final force = args?['force'] as bool? ?? false;
  
  // Get option values
  final configPath = args?['config'] as String?;
  
  // Get positional arguments
  final files = args?.rest ?? [];
  
  // Get multi-option values
  final selectedFiles = args?['files'] as List<String>? ?? [];
}
```

## Best Practices

### 1. Error Handling
```dart
@override
void executeCommand() {
  try {
    // Command logic
    await performOperation();
  } catch (e) {
    // Log error and provide helpful message
    logger.severe('Command failed: $e');
    print('Error: $e');
    print('Use --help for usage information');
    exit(1);
  }
}
```

### 2. Input Validation
```dart
@override
void executeCommand() {
  final configPath = argResults?['config'] as String?;
  
  if (configPath == null) {
    print('Error: Configuration path is required');
    exit(1);
  }
  
  final configFile = File(configPath);
  if (!configFile.existsSync()) {
    print('Error: Configuration file does not exist: $configPath');
    exit(1);
  }
  
  // Continue with validated input
}
```

### 3. Progress Reporting
```dart
@override
void executeCommand() async {
  // Access the UI handler for progress reporting
  final uiHandler = configManager.uiHandler;
  
  // Emit events for UI updates
  uiHandler.handleEvent(StartedEvent(
    moduleId: 'my-command',
    message: 'Starting operation',
  ));
  
  for (int i = 0; i < items.length; i++) {
    // Update progress
    uiHandler.handleEvent(ProgressEvent(
      moduleId: 'my-command',
      current: i + 1,
      total: items.length,
      message: 'Processing item ${i + 1}',
    ));
    
    // Process item
    await processItem(items[i]);
  }
  
  // Complete
  uiHandler.handleEvent(CompletedEvent(
    moduleId: 'my-command',
    message: 'Operation completed successfully',
  ));
}
```

### 4. Configuration Access
```dart
@override
void executeCommand() async {
  // Load configuration
  await configManager.load();
  
  // Access configuration data
  final config = configManager.config;
  final options = configManager.options;
  
  // Use configuration in your command logic
  if (options.verbose) {
    print('Configuration loaded: ${config.files.length} files');
  }
}
```

## Example Commands

### Simple Command
```dart
class ListCommand extends BaseCommand {
  @override
  String get name => 'list';

  @override
  String get description => 'List configuration files';

  @override
  void executeCommand() async {
    await configManager.load();
    final files = configManager.config.files;
    
    print('Configuration files:');
    for (final file in files) {
      print('  - ${file.source}');
    }
  }
}
```

### Complex Command with Options
```dart
class BackupCommand extends BaseCommand {
  BackupCommand() {
    argParser.addOption(
      'destination',
      abbr: 'd',
      help: 'Backup destination directory',
      defaultsTo: './backup',
    );
    argParser.addFlag(
      'compress',
      help: 'Compress backup files',
      defaultsTo: true,
    );
    argParser.addOption(
      'format',
      help: 'Backup format (tar, zip)',
      defaultsTo: 'tar',
    );
  }

  @override
  String get name => 'backup';

  @override
  String get description => 'Create configuration backup';

  @override
  void executeCommand() async {
    final destination = argResults?['destination'] as String? ?? './backup';
    final compress = argResults?['compress'] as bool? ?? true;
    final format = argResults?['format'] as String? ?? 'tar';
    
    // Validate format
    if (!['tar', 'zip'].contains(format)) {
      print('Error: Invalid format. Use "tar" or "zip"');
      exit(1);
    }
    
    print('Creating backup...');
    print('Destination: $destination');
    print('Compress: $compress');
    print('Format: $format');
    
    // Implement backup logic
    await createBackup(destination, compress, format);
  }
}
```

## Testing Commands

### Unit Tests
```dart
import 'package:test/test.dart';
import 'package:configr/commands/my_command.dart';

void main() {
  group('MyCommand', () {
    test('should have correct name and description', () {
      final command = MyCommand();
      expect(command.name, equals('my-command'));
      expect(command.description, isNotEmpty);
    });
    
    test('should parse arguments correctly', () {
      final command = MyCommand();
      command.configManager = mockConfigManager;
      
      // Test argument parsing
      expect(command.argParser.options.containsKey('verbose'), isTrue);
      expect(command.argParser.options.containsKey('output'), isTrue);
    });
  });
}
```

### Integration Tests
```dart
void main() {
  group('MyCommand Integration', () {
    test('should execute successfully with valid arguments', () async {
      final command = MyCommand();
      command.configManager = realConfigManager;
      
      // Mock stdin for input
      // Execute command
      // Verify results
    });
  });
}
```

## Migration from Old Commands

If you have existing commands using the old architecture:

### Before (Old Command)
```dart
class OldCommand extends Command {
  final ConfigManager configManager;
  
  OldCommand(this.configManager);
  
  @override
  Future<void> execute() async {
    // Command logic
  }
}
```

### After (New Command)
```dart
class NewCommand extends BaseCommand {
  NewCommand() {
    // Add options and arguments
  }
  
  @override
  String get name => 'command-name';
  
  @override
  String get description => 'Command description';
  
  @override
  void executeCommand() {
    // Command logic - configManager is available via getter
  }
}
```

## Resources

- [CommandRunner Documentation](https://pub.dev/packages/args)
- [Dart CLI Best Practices](https://dart.dev/tools/dart-tool)
- [Configr Configuration Guide](../configuration.md)
