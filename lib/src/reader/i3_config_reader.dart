import 'package:configr/src/exceptions.dart';
import 'package:configr/src/models/config.dart';
import 'package:configr/src/reader/config_builder.dart';
import 'package:configr/src/reader/handlers/configr_handlers.dart';
import 'package:i3config/i3config.dart' as i3;

/// Reads and parses i3-style configuration files using i3config v2.
///
/// Uses [i3.Config.parse] for parsing and the Configr handler pipeline
/// (see [createConfigrProcessor]) to build the domain model via the
/// i3config v2 [i3.ConfigProcessor] state machine.
class I3ConfigReader {
  /// Parse i3 config text into a Configr [Config] model.
  ///
  /// Throws [SourceNotFoundException] if parsing fails.
  Future<Config> read(String contents, {Uri? sourceUri}) async {
    i3.Config v2Config;
    try {
      v2Config = i3.Config.parse(contents, url: sourceUri);
    } catch (e, s) {
      final sourceInfo = sourceUri != null
          ? ' in ${sourceUri.toFilePath()}'
          : '';
      throw SourceNotFoundException(sourceInfo, cause: e, stackTrace: s);
    }

    final builder = ConfigBuilder();
    final processor = createConfigrProcessor(builder);
    await processor.process(v2Config);
    return builder.build();
  }

  /// Parse i3 config text with detailed error information.
  ///
  /// Returns a [I3ParseResult] instead of throwing, allowing callers to inspect
  /// error details.
  Future<I3ParseResult> parseWithDetails(
    String contents, {
    Uri? sourceUri,
  }) async {
    try {
      final v2Config = i3.Config.parse(contents, url: sourceUri);
      final builder = ConfigBuilder();
      final processor = createConfigrProcessor(builder);
      await processor.process(v2Config);
      return I3ParseResult.success(builder.build());
    } catch (e, s) {
      return I3ParseResult.failure(
        'Failed to parse config${sourceUri != null ? ' at ${sourceUri.toFilePath()}' : ''}',
        error: e,
        stackTrace: s,
      );
    }
  }
}

/// Result of parsing an i3 config file through [I3ConfigReader.parseWithDetails].
class I3ParseResult {
  final Config? config;
  final String? errorMessage;
  final Object? error;
  final StackTrace? stackTrace;

  I3ParseResult._({
    this.config,
    this.errorMessage,
    this.error,
    this.stackTrace,
  });

  factory I3ParseResult.success(Config config) =>
      I3ParseResult._(config: config);

  factory I3ParseResult.failure(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => I3ParseResult._(
    errorMessage: message,
    error: error,
    stackTrace: stackTrace,
  );

  bool get isSuccess => config != null;
  bool get isFailure => !isSuccess;
}
