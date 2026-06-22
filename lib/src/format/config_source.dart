import 'package:file/file.dart';
import 'package:file/local.dart';

/// Metadata about where a configuration is read from.
///
/// Carries the path, URI, and file system so format services and readers
/// can locate and load the configuration regardless of storage backend.
class ConfigSource {
  /// The file path (may be relative or absolute).
  final String? path;

  /// The resolved URI for the source.
  final Uri? uri;

  /// The file system to use for reading.
  final FileSystem fileSystem;

  const ConfigSource({
    this.path,
    this.uri,
    this.fileSystem = const LocalFileSystem(),
  });

  /// Create a [ConfigSource] from a file path.
  factory ConfigSource.fromPath(
    String path, {
    FileSystem fileSystem = const LocalFileSystem(),
  }) {
    return ConfigSource(
      path: path,
      uri: Uri.file(path),
      fileSystem: fileSystem,
    );
  }

  /// Read the content from this source as a string.
  Future<String> readContent() async {
    if (path != null) {
      final file = fileSystem.file(path);
      if (await file.exists()) {
        return file.readAsString();
      }
    }
    throw ArgumentError('Cannot read from source without a valid path or URI');
  }

  @override
  String toString() => 'ConfigSource(${path ?? uri})';
}

/// Metadata about where a configuration is written to.
///
/// Carries the path, URI, and file system so format services and writers
/// can produce output to the correct location.
class ConfigSink {
  /// The file path (may be relative or absolute).
  final String? path;

  /// The resolved URI for the sink.
  final Uri? uri;

  /// The file system to use for writing.
  final FileSystem fileSystem;

  const ConfigSink({
    this.path,
    this.uri,
    this.fileSystem = const LocalFileSystem(),
  });

  /// Create a [ConfigSink] from a file path.
  factory ConfigSink.fromPath(
    String path, {
    FileSystem fileSystem = const LocalFileSystem(),
  }) {
    return ConfigSink(path: path, uri: Uri.file(path), fileSystem: fileSystem);
  }

  /// Write [content] to this sink.
  Future<void> writeContent(String content) async {
    if (path != null) {
      final file = fileSystem.file(path);
      await file.writeAsString(content);
    } else {
      throw ArgumentError('Cannot write to sink without a valid path or URI');
    }
  }

  @override
  String toString() => 'ConfigSink(${path ?? uri})';
}
