import 'package:archive/archive.dart';
import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:glob/glob.dart';
import 'package:i3config/i3config_v2.dart' as i3;
import 'package:path/path.dart' show posix;

/// Block handler for the `decompress` config action.
///
/// Extracts compressed archives (zip, tar, tar.gz, etc.) to a destination.
///
/// ```i3
/// decompress {
///   source = "/path/to/archive.zip"
///   destination = "/path/to/output"
///   format = "zip"            # zip | tar | tar.gz | tgz | gz | tar.bz2 | tbz2
///   include = "*.dart"
///   exclude = "*.tmp"
///   preserve_structure = true
/// }
/// ```
class DecompressBlock extends ActionBlock {
  @override
  String get blockType => 'decompress';

  // ---------------------------------------------------------------------------
  // Decompress-specific properties
  // ---------------------------------------------------------------------------

  String format = 'zip';
  List<String> includePatterns = [];
  List<String> excludePatterns = [];
  bool preserveStructure = true;

  // ---------------------------------------------------------------------------
  // Execution state
  // ---------------------------------------------------------------------------

  bool sourceExists = false;
  int totalFiles = 0;
  int extractedFiles = 0;
  int compressedSize = 0;
  int uncompressedSize = 0;
  List<String> createdFiles = [];

  DecompressBlock();

  // ---------------------------------------------------------------------------
  // Handler pipeline
  // ---------------------------------------------------------------------------

  @override
  Map<String, String> get additionalProperties => {
    if (format != 'zip') 'format': format,
    if (includePatterns.isNotEmpty) 'include': includePatterns.join(', '),
    if (excludePatterns.isNotEmpty) 'exclude': excludePatterns.join(', '),
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (!preserveStructure) 'preserve_structure': preserveStructure,
  };

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);

    format = context.getVariable('format') as String? ?? format;

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
      StartedEvent(moduleId: id, message: 'Starting decompression of $source'),
    );

    if (!_isSupportedFormat(format)) {
      throw ActionFailedException(
        'Unsupported decompression format: $format. '
        'Supported: zip, tar, tar.gz, tgz, gz, tar.bz2, tbz2, tar.xz, txz, xz, tar.z, tz, z',
        moduleId: id,
      );
    }

    final exists = await fileService.fileExists(source);
    sourceExists = exists;
    if (!exists) {
      throw SourceNotFoundException(source);
    }

    // Execute child blocks
    for (final child in children) {
      await child.execute();
    }

    try {
      emitEvent(
        ProgressEvent(
          moduleId: id,
          current: 0,
          total: 1,
          message: 'Reading archive...',
        ),
      );

      final data = await fileService.readBinaryFile(source);
      compressedSize = data.length;
      final archive = _decodeArchive(data, format);
      totalFiles = archive.files.length;

      await _extractArchive(archive);

      final deflationPct = uncompressedSize > 0
          ? ((1 - compressedSize / uncompressedSize) * 100).toStringAsFixed(1)
          : 'N/A';
      emitEvent(
        CompletedEvent(
          moduleId: id,
          message:
              'Decompression completed. Extracted $extractedFiles files (deflated $deflationPct%).',
        ),
      );
      emitEvent(
        StatusUpdateEvent(
          moduleId: id,
          level: StatusEvent.info,
          message: 'Extracted $extractedFiles files (deflated $deflationPct%)',
        ),
      );
    } catch (e, _) {
      emitEvent(FailedEvent(moduleId: id, message: 'Decompression failed: $e'));
      throw ActionFailedException(
        'Failed to decompress $source',
        cause: e,
        moduleId: id,
      );
    }

    status = 'completed';
  }

  @override
  Future<void> rollback() async {
    // Remove the entire destination directory
    if (await fileService.directoryExists(destination)) {
      await fileService.deleteDirectory(destination, recursive: true);
    }

    for (final child in children) {
      await child.rollback();
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<void> _extractArchive(Archive archive) async {
    // Ensure destination directory exists
    if (!await fileService.directoryExists(destination)) {
      await fileService.createDirectory(destination);
    }

    for (final file in archive) {
      if (_shouldExtractFile(file.name)) {
        final filePath = preserveStructure
            ? fileSystem.path.join(destination, file.name)
            : fileSystem.path.join(destination, posix.basename(file.name));

        if (file.isFile) {
          final dir = fileSystem.path.dirname(filePath);
          if (!await fileService.directoryExists(dir)) {
            await fileService.createDirectory(dir);
          }
          await fileService.writeFile(
            filePath,
            String.fromCharCodes(file.content),
          );
          createdFiles.add(filePath);
          extractedFiles++;
          uncompressedSize += file.size;
        } else {
          await fileService.createDirectory(filePath);
        }

        if (extractedFiles % 10 == 0 || extractedFiles == totalFiles) {
          final pct = uncompressedSize > 0
              ? ((1 - compressedSize / uncompressedSize) * 100).toStringAsFixed(
                  1,
                )
              : 'N/A';
          emitEvent(
            ProgressEvent(
              moduleId: id,
              current: extractedFiles,
              total: totalFiles,
              message: 'Extracting files... ($pct% deflated)',
            ),
          );
        }
      }
    }
  }

  Archive _decodeArchive(List<int> data, String fmt) {
    switch (fmt.toLowerCase()) {
      case 'zip':
        return ZipDecoder().decodeBytes(data);
      case 'tar':
        return TarDecoder().decodeBytes(data);
      case 'tar.gz':
      case 'tgz':
        return TarDecoder().decodeBytes(GZipDecoder().decodeBytes(data));
      case 'tar.bz2':
      case 'tbz2':
        return TarDecoder().decodeBytes(BZip2Decoder().decodeBytes(data));
      case 'gz':
        final gzipData = GZipDecoder().decodeBytes(data);
        final archive = Archive();
        final fileName = fileSystem.path.basename(source);
        final outName = fileName.endsWith('.gz')
            ? fileName.substring(0, fileName.length - 3)
            : fileName;
        archive.addFile(ArchiveFile(outName, gzipData.length, gzipData));
        return archive;
      case 'tar.xz':
      case 'txz':
        return TarDecoder().decodeBytes(XZDecoder().decodeBytes(data));
      case 'xz':
        final xzData = XZDecoder().decodeBytes(data);
        final archive = Archive();
        final fileName = fileSystem.path.basename(source);
        final outName = fileName.endsWith('.xz')
            ? fileName.substring(0, fileName.length - 3)
            : fileName;
        archive.addFile(ArchiveFile(outName, xzData.length, xzData));
        return archive;
      case 'tar.z':
      case 'tz':
        return TarDecoder().decodeBytes(ZLibDecoder().decodeBytes(data));
      case 'z':
        final zlibData = ZLibDecoder().decodeBytes(data);
        final archive = Archive();
        final fileName = fileSystem.path.basename(source);
        final outName = fileName.endsWith('.z')
            ? fileName.substring(0, fileName.length - 2)
            : fileName;
        archive.addFile(ArchiveFile(outName, zlibData.length, zlibData));
        return archive;
      default:
        throw ActionFailedException('Unsupported format: $fmt', moduleId: id);
    }
  }

  bool _shouldExtractFile(String fileName) {
    if (includePatterns.isEmpty && excludePatterns.isEmpty) return true;

    for (final pattern in excludePatterns) {
      if (_matchesPattern(fileName, pattern)) return false;
    }

    if (includePatterns.isNotEmpty) {
      for (final pattern in includePatterns) {
        if (_matchesPattern(fileName, pattern)) return true;
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
