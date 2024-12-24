abstract class ModuleException implements Exception {
  final String message;
  final dynamic cause;
  final StackTrace? stackTrace;

  ModuleException(this.message, [this.cause, this.stackTrace]);

  @override
  String toString() =>
      'ModuleException: $message${cause != null ? '\nCause: $cause' : ''}';
}

class SourceNotFoundException extends ModuleException {
  SourceNotFoundException(String path, [dynamic cause, StackTrace? stackTrace])
      : super('Source path not found: $path', cause, stackTrace);
}

class DestinationExistsException extends ModuleException {
  DestinationExistsException(String path,
      [dynamic cause, StackTrace? stackTrace])
      : super('Destination already exists: $path', cause, stackTrace);
}

class ActionFailedException extends ModuleException {
  ActionFailedException(super.message, [super.cause, super.stackTrace]);
}

class ValidationFailedException extends ModuleException {
  ValidationFailedException(super.message, [super.cause, super.stackTrace]);
}

class PermissionDeniedException extends ModuleException {
  PermissionDeniedException(String path,
      [dynamic cause, StackTrace? stackTrace])
      : super('Permission denied: $path', cause, stackTrace);
}

class ChecksumValidationException extends ModuleException {
  ChecksumValidationException(String path, String expected, String actual)
      : super(
            'Checksum validation failed for $path\nExpected: $expected\nActual: $actual');
}

class FormatValidationException extends ModuleException {
  FormatValidationException(String path, String format, [dynamic cause])
      : super('Format validation failed for $path: $format', cause);
}

class CommandExecutionException extends ModuleException {
  CommandExecutionException(String command,
      [dynamic cause, StackTrace? stackTrace])
      : super('Command execution failed: $command', cause, stackTrace);
}

class SymlinkCreationException extends ModuleException {
  SymlinkCreationException(String path, [dynamic cause])
      : super('Failed to create symlink: $path', cause);
}

class ConfigurationFailedException extends ModuleException {
  final List<ModuleException> errors;

  ConfigurationFailedException(this.errors)
      : super(
            'Multiple configuration errors occurred:\n${errors.map((e) => '- ${e.message}').join('\n')}');
}
