# Terminal UI System

## Overview

The terminal UI system provides a simple, text-focused interface for displaying module progress, status updates, and user feedback. It uses straightforward text output without fancy terminal features for maximum compatibility and readability.

## Features

### Simple Text Output
- **Clean Format**: `🔄 [module-id] Starting: message`
- **Visual Progress**: Progress bars with percentage indicators
- **Multiple Modules**: Support for concurrent module execution with individual status tracking

### Status Messages
- **🔄 Starting**: When operations begin
- **📊 Progress**: Current progress with visual progress bar and percentage
- **✅ Completed**: Successfully completed operations
- **❌ Failed**: Failed operations with error details
- **⚠️ Warnings**: Status updates and warning messages
- **ℹ️ Info**: Informational messages
- **📦 Resource Started**: Resource-level operation beginning with source/destination info
- **✅ Resource Completed**: Resource-level operation finished with timing and action count
- **🔄 Resource Rollback Started**: Resource-level rollback beginning with source/destination info
- **✅ Resource Rollback Completed**: Resource-level rollback finished with timing and action count

### Interactive Support
- **Password Prompts**: Integrated with privilege escalation, pauses UI output during prompts
- **User Confirmations**: Clear prompts for destructive operations
- **Simple Input**: Standard input handling without terminal manipulation

## Technical Implementation

### Simple Text Output
The UI system uses straightforward text output:
- **Direct Print**: Simple `print()` statements for each event
- **No Terminal Manipulation**: No cursor control or screen buffer management
- **Line-by-Line Output**: Each event gets its own line for clarity

### Performance Benefits
- **Minimal Overhead**: No complex terminal operations
- **Universal Compatibility**: Works with any terminal or output stream
- **Easy to Parse**: Simple text format for logging and automation
- **No Dependencies**: Pure Dart implementation without external libraries

### Event Handling
The UI system responds to various module events:

```dart
// Started events show loading indicator
StartedEvent(moduleId: 'module-1', message: 'Starting operation')

// Progress events show progress bars
ProgressEvent(moduleId: 'module-1', current: 50, total: 100, message: 'Processing...')

// Completed events show success
CompletedEvent(moduleId: 'module-1', message: 'Operation completed')

// Failed events show error
FailedEvent(moduleId: 'module-1', message: 'Operation failed')

// Status updates show warnings/info
StatusUpdateEvent(moduleId: 'module-1', level: StatusEvent.warning, message: 'Warning message')
```

## Usage Examples

### Basic Module Execution
```
🔄 [backup] Starting configuration backup
📊 [backup] [====================] 100% - Backup completed successfully
✅ [backup] Backup completed successfully
```

### Resource-Level Operations
```
📦 Starting resource: package-manager
   📍 Source: /tmp → /tmp
   🔧 Actions: 3
🔄 [package_1] Starting package management operation
📊 [package_1] [==========          ] 50% - Installing packages...
✅ [package_1] Package management operation completed successfully
✅ Resource completed: package-manager
   ⏱️  Duration: 1250ms
   📊 Actions: 3/3
```

### Multiple Concurrent Modules
```
🔄 [copy] Starting file copy operation
🔄 [validation] Starting configuration validation
📊 [copy] [==========          ] 50% - Processing files...
✅ [copy] File copy completed successfully
✅ [validation] Validation completed successfully
```

### Rollback Operations
```
🔄 Rolling back resource: download-resource
   📍 Source: https://example.com/file.txt → /tmp/file.txt
   🔧 Actions: 2
🔄 [download_1] Rolling back download operation for /tmp/file.txt
ℹ️ [download_1] Removing downloaded file /tmp/file.txt (rollback)
✅ [download_1] Download rollback completed for /tmp/file.txt
✅ Resource rollback completed: download-resource
   ⏱️  Duration: 450ms
   📊 Actions: 2/2
```

### Error Handling
```
🔄 [file-op] Starting file operation
❌ [file-op] File operation failed: Permission denied
🔄 [file-op] Retrying operation (2/3)
✅ [file-op] File operation completed successfully
```

## Configuration

### Interactive Mode Control
```dart
// Enable interactive mode (pauses UI output)
handler.enableInteractiveMode();

// Perform user interaction
final input = stdin.readLineSync();

// Disable interactive mode (resumes UI output)
handler.disableInteractiveMode();
```

### Password Prompt Mode
```dart
// Enable password prompt mode (pauses UI output)
handler.enablePasswordPromptMode();

// Secure password input
final password = stdin.readLineSync();

// Disable password prompt mode (resumes UI output)
handler.disablePasswordPromptMode();
```

## Benefits

The text-focused UI system provides several advantages:

| Benefit | Description |
|---------|-------------|
| **Universal Compatibility** | Works with any terminal, CI/CD system, or output stream |
| **Easy to Parse** | Simple text format perfect for logging and automation |
| **No Dependencies** | Pure Dart implementation without external libraries |
| **Minimal Overhead** | No complex terminal operations or screen manipulation |
| **Debug Friendly** | Easy to capture and analyze output for troubleshooting |

## Best Practices

### For Developers
1. **Use Event-Driven Updates**: Emit appropriate events for UI state changes
2. **Provide Clear Messages**: Use descriptive messages for better user experience
3. **Handle Errors Gracefully**: Always emit failed events with clear error messages
4. **Batch Operations**: Group related operations to minimize UI updates

### For Users
1. **Monitor Progress**: Watch progress bars for long-running operations
2. **Read Status Messages**: Pay attention to status indicators and messages
3. **Handle Prompts**: Respond to interactive prompts when they appear
4. **Check Results**: Review completion status and error messages

## Troubleshooting

### Common Issues
- **Screen Not Clearing**: Ensure terminal supports ANSI escape sequences
- **Progress Not Showing**: Check that modules are emitting progress events
- **Flickering**: Update to the latest version with the new UI system

### Terminal Compatibility
The UI system is compatible with:
- **Linux**: Full support for all features
- **macOS**: Full support for all features  
- **Windows**: Limited support (use Windows Terminal or WSL for best experience)

### Debug Mode
Enable debug output to troubleshoot UI issues:
```bash
dart bin/main.dart --verbose <command>
```
