import 'package:archive/archive.dart';
import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/file_utils.dart';
import 'package:configr/src/utils/fs.dart' show fs;
import 'package:file/file.dart' show File;
import 'package:glob/glob.dart';
import 'package:i3config/i3config_v2.dart' as i3;
import 'package:path/path.dart' as path;

/// Block handler for the `compress` config action.
///
/// Creates compressed archives (zip, tar, tar.gz, etc.) from files/directories.
///
/// ```i3
/// compress {
///   source = "/path/to/source"
///   destination = "/path/to/archive.zip"
///   format = "zip"            # zip | tar | tar.gz | tgz | gz | tar.bz2 | tbz2
///   compression_level = 6     # 1-9
///   recursive = true
///   include = "*.dart"
///   exclude = "*.tmp"
///   preserve_structure = true
/// }
/// ```
class CompressBlock extends ActionBlock {
  @override
  String get blockType => 'compress';

  // ---------------------------------------------------------------------------
  // Compress-specific properties
  // ---------------------------------------------------------------------------

  String format = 'zip';
  int compressionLevel = 6;
  bool recursive = false;
  List<String> includePatterns = [];
  List<String> excludePatterns = [];
  bool preserveStructure = true;

  // ---------------------------------------------------------------------------
  // Execution state
  // ---------------------------------------------------------------------------

  bool destinationFileExisted = false;

  CompressBlock({super.fileSystem, super.eventBus});

  // ---------------------------------------------------------------------------
  // Handler pipeline
  // ---------------------------------------------------------------------------

  @override
  Map<String, String> get additionalProperties => {
    if (format != 'zip') 'format': format,
    if (compressionLevel != 6) 'compression_level': compressionLevel.toString(),
    if (includePatterns.isNotEmpty) 'include': includePatterns.join(', '),
    if (excludePatterns.isNotEmpty) 'exclude': excludePatterns.join(', '),
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (recursive) 'recursive': recursive,
    if (!preserveStructure) 'preserve_structure': preserveStructure,
  };

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);

    format = context.getVariable('format') as String? ?? format;

    final level = context.getVariable('compression_level');
    if (level is int) compressionLevel = level.clamp(1, 9);
    if (level is String) {
      compressionLevel = int.tryParse(level)?.clamp(1, 9) ?? 6;
    }

    recursive = switch (context.getVariable('recursive')) {
      true || 'true' => true,
      _ => false,
    };

    final include = context.getVariable('include');
    if (include is String) {
      includePatterns = include.split(',').map((s) => s.trim()).toList();
    } else if (include is List) {
      includePatterns = include.cast<String>();
    }

    final exclude = context.getVariable('exclude');
    if (exclude is String) {
      excludePatterns = exclude.split(',').map((s) => s.trim()).toList();
    } else if (exclude is List) {
      excludePatterns = exclude.cast<String>();
    }

    preserveStructure = switch (context.getVariable('preserve_structure')) {
      false || 'false' => false,
      _ => true,
    };
  }

  // ---------------------------------------------------------------------------
  // Execution
  // ---------------------------------------------------------------------------

  @override
  Future<void> execute() async {
    emitEvent(
      StartedEvent(moduleId: id, message: 'Starting compression of $source'),
    );

    if (!_isSupportedFormat(format)) {
      throw ActionFailedException(
        'Unsupported compression format: $format. '
        'Supported: zip, tar, tar.gz, tgz, gz, tar.bz2, tbz2, tar.xz, txz, xz, tar.z, tz, z',
        moduleId: id,
      );
    }

    final pathExists = await FileUtils.pathExists(
      source,
      fileSystem: fileSystem,
    );
    if (!pathExists.exists) {
      throw SourceNotFoundException(source);
    }

    final exists = await FileUtils.fileExists(
      destination,
      fileSystem: fileSystem,
    );
    destinationFileExisted = exists;

    // Execute child blocks
    for (final child in children) {
      await child.execute();
    }

    try {
      emitEvent(
        StatusUpdateEvent(
          moduleId: id,
          level: StatusEvent.info,
          message: 'Compressing files...',
        ),
      );

      List<int> compressedData;
      if (pathExists.isDir) {
        compressedData = await _compressDirectory(source);
      } else {
        compressedData = await _compressFile(source);
      }

      // Ensure destination parent dir exists
      final destDir = path.dirname(destination);
      if (!await FileUtils.directoryExists(destDir, fileSystem: fileSystem)) {
        await FileUtils.createDirectory(destDir, fileSystem: fileSystem);
      }

      if (exists) {
        await FileUtils.deleteFile(destination, fileSystem: fileSystem);
      }

      await (fileSystem ?? fs).file(destination).writeAsBytes(compressedData);

      emitEvent(CompletedEvent(moduleId: id, message: 'Compression completed'));
    } catch (e, _) {
      emitEvent(FailedEvent(moduleId: id, message: 'Compression failed: $e'));
      throw ActionFailedException(
        'Failed to compress $source → $destination',
        cause: e,
        moduleId: id,
      );
    }

    status = 'completed';
  }

  @override
  Future<void> rollback() async {
    if (!destinationFileExisted) {
      if (await FileUtils.fileExists(destination, fileSystem: fileSystem)) {
        await FileUtils.deleteFile(destination, fileSystem: fileSystem);
      }
    }

    for (final child in children) {
      await child.rollback();
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<List<int>> _compressDirectory(String dirPath) async {
    final archive = Archive();
    await _addDirectoryToArchive(dirPath, archive);
    return _encodeArchive(archive);
  }

  Future<List<int>> _compressFile(String filePath) async {
    if (!_shouldIncludeFile(filePath)) {
      throw ActionFailedException(
        'File $filePath is excluded by patterns',
        moduleId: id,
      );
    }

    final content = await FileUtils.readFile(filePath, fileSystem: fileSystem);
    final archive = Archive();
    final fileName = path.basename(filePath);

    final archiveFile = ArchiveFile(
      fileName,
      content.length,
      content.codeUnits,
    );
    if (compressionLevel != 6) {
      archiveFile.compressionLevel = compressionLevel;
    }
    archive.addFile(archiveFile);

    return _encodeArchive(archive);
  }

  List<int> _encodeArchive(Archive archive) {
    switch (format.toLowerCase()) {
      case 'zip':
        return ZipEncoder().encode(archive);
      case 'tar':
        return TarEncoder().encode(archive);
      case 'tar.gz':
      case 'tgz':
        final tarData = TarEncoder().encode(archive);
        return GZipEncoder().encode(tarData);
      case 'gz':
        if (archive.files.length == 1) {
          final file = archive.files.first;
          return GZipEncoder().encode(file.content as List<int>);
        }
        throw ActionFailedException(
          'GZ format only supports single files',
          moduleId: id,
        );
      case 'tar.bz2':
      case 'tbz2':
        final tarData = TarEncoder().encode(archive);
        return BZip2Encoder().encode(tarData);
      case 'tar.xz':
      case 'txz':
        final tarData = TarEncoder().encode(archive);
        return XZEncoder().encode(tarData);
      case 'xz':
        if (archive.files.length == 1) {
          final file = archive.files.first;
          return XZEncoder().encode(file.content as List<int>);
        }
        throw ActionFailedException(
          'XZ format only supports single files',
          moduleId: id,
        );
      case 'tar.z':
      case 'tz':
        final tarData = TarEncoder().encode(archive);
        return ZLibEncoder().encode(tarData);
      case 'z':
        if (archive.files.length == 1) {
          final file = archive.files.first;
          return ZLibEncoder().encode(file.content as List<int>);
        }
        throw ActionFailedException(
          'Z format only supports single files',
          moduleId: id,
        );
      default:
        throw ActionFailedException(
          'Unsupported format: $format',
          moduleId: id,
        );
    }
  }

  Future<void> _addDirectoryToArchive(String dirPath, Archive archive) async {
    final dir = fileSystem!.directory(dirPath);
    await for (final entity in dir.list(recursive: recursive)) {
      if (entity is File && _shouldIncludeFile(entity.path)) {
        final relativePath = preserveStructure
            ? path.relative(entity.path, from: dirPath)
            : path.basename(entity.path);
        final content = await FileUtils.readFile(
          entity.path,
          fileSystem: fileSystem,
        );

        final archiveFile = ArchiveFile(
          relativePath,
          content.length,
          content.codeUnits,
        );
        if (compressionLevel != 6) {
          archiveFile.compressionLevel = compressionLevel;
        }
        archive.addFile(archiveFile);

        emitEvent(
          StatusUpdateEvent(
            moduleId: id,
            level: StatusEvent.info,
            message: 'Added: $relativePath',
          ),
        );
      }
    }
  }

  bool _shouldIncludeFile(String filePath) {
    if (includePatterns.isEmpty && excludePatterns.isEmpty) return true;

    for (final pattern in excludePatterns) {
      if (_matchesPattern(filePath, pattern)) return false;
    }

    if (includePatterns.isNotEmpty) {
      for (final pattern in includePatterns) {
        if (_matchesPattern(filePath, pattern)) return true;
      }
      return false;
    }

    return true;
  }

  bool _matchesPattern(String text, String pattern) {
    try {
      return Glob(pattern).matches(text);
    } catch (_) {
      return text.contains(pattern);
    }
  }

  bool _isSupportedFormat(String fmt) {
    const supported = [
      'zip',
      'tar',
      'tar.gz',
      'tgz',
      'gz',
      'tar.bz2',
      'tbz2',
      'tar.xz',
      'txz',
      'xz',
      'tar.z',
      'tz',
      'z',
    ];
    return supported.contains(fmt.toLowerCase());
  }
}
